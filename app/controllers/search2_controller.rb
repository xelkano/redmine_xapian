
begin
    require 'xapian'
    $xapian_bindings_available = true
rescue LoadError
    logger.notice "No Ruby bindings for Xapian installed"
    $xapian_bindings_available = false
end

require 'filedoc.rb'

class Search2Controller < ApplicationController
	unloadable
   	before_filter :find_optional_project

  	helper :messages
  	include MessagesHelper

	def initialize
	end

	def index
	end
	

	def do_search
		@question = params[:q] || ""
                @question.strip!
		@all_words = params[:all_words] || (params[:submit] ? false : true)
		@titles_only = !params[:titles_only].nil?
		scope = params[:scope]
		previous = nil
		previous = params[:previous]
		logger.debug "DEBUG: question: " + @question.inspect
		offset = nil
                begin; offset = params[:offset].to_time if params[:offset]; rescue; end
		
		# quick jump to an issue
                if @question.match(/^#?(\d+)$/) && Issue.visible.find_by_id($1.to_i)
                        redirect_to :controller => "issues", :action => "show", :id => $1
                        return
                end

		# extract tokens from the question
                # eg. hello "bye bye" => ["hello", "bye bye"]
                @tokens = @question.scan(%r{((\s|^)"[\s\w]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
                # tokens must be at least 2 characters long
                @tokens = @tokens.uniq.select {|w| w.length > 1 }
		@tokens.slice! 5..-1 if @tokens.size > 5

		projects_to_search =
      		case scope
      		when 'all'
        		nil
      		when 'my_projects'
        		User.current.memberships.collect(&:project)
      		when 'subprojects'
        		@project ? (@project.self_and_descendants.active) : nil
      		else
        		@project
      		end
 
    		@object_types = Redmine::Search.available_search_types.dup
		@object_types.push ("attachments")
    		if projects_to_search.is_a? Project
      		  # don't search projects
      		  @object_types.delete('projects')
      		  # only show what the user is allowed to view
      		  @object_types = @object_types.select {|o| User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)}
		  @object_types.pop ("attachments") if not @object_types.include?("documents")
    		end
 
    		@scope = @object_types.select {|t| params[t]}
    		@scope = @object_types if @scope.empty?
	 

		if !@tokens.empty?
      		# no more than 5 tokens to search for
      			@results = []
      			@results_by_type = Hash.new {|h,k| h[k] = 0}
      			logger.debug "all_words: " + @all_words.inspect
      			limit = 50
      			@scope.each do |s|
			  unless s == "attachments"
        		    r, c = s.singularize.camelcase.constantize.search(@tokens, projects_to_search,
          		    :all_words => @all_words,
          		    :titles_only => @titles_only,
          		    :limit => (limit+1),
          		    :offset => offset,
          		    :before => previous.nil? )
			  else
			     r, c = getFileDocs(offset, limit+1, previous.nil?, projects_to_search) 
			  end
        		  @results += r
        		  @results_by_type[s] += c
      			end
			@results = @results.sort {|a,b| b.event_datetime <=> a.event_datetime} if !@results.nil?
      			if previous.nil?
        		  @pagination_previous_date = @results[0].event_datetime if offset && @results[0]
        		  if @results.size > limit
          		 	@pagination_next_date = @results[limit-1].event_datetime 
          			@results = @results[0, limit]
        		  end
      			else
        		  @pagination_next_date = @results[-1].event_datetime if offset && @results[-1]
        		  if @results.size > limit
          			@pagination_previous_date = @results[-(limit)].event_datetime 
          			@results = @results[-(limit), limit]
        		  end
      			end
    		else
      			@question = ""
    		end
		render :layout => false if request.xhr?
  end


  private

  def getFileDocs( offset, limit, before, projects_to_search) 
		filterdocs = Array.new
		filedocs = Array.new
		return [filterdocs, 0] unless Setting.plugin_redmine_xapian['enable'] == "true"
		# Open the database for searching.stemming_lang
		logger.debug "DEBUG: offset: " + offset.to_s + "limit: " + limit.to_s
		logger.debug "DEBUG: index_database: " + Setting.plugin_redmine_xapian['index_database'].rstrip
		logger.debug "DEBUG: stemming lang: " + Setting.plugin_redmine_xapian.inspect
		filedocs=search_attachments(projects_to_search)
		docs_count = filedocs.size
		filterdocs=filedocs if offset.nil?
		unless offset.nil?
		  filedocs.each {|doc|
		    if before
		      if doc.event_datetime < offset
			filterdocs.push (doc) if filterdocs.size < limit  
		      end
		    else
		      if doc.event_datetime > offset
                        filterdocs.push (doc) if filterdocs.size < limit
                      end
		    end
		  }			
		end
		[filterdocs, docs_count]
  end

  def search_attachments(projects_to_search )
		filedocs = Array.new
		database = Xapian::Database.new(Setting.plugin_redmine_xapian['index_database'].rstrip)

		# Start an enquire session.
		enquire = Xapian::Enquire.new(database)

		# Combine the rest of the command line arguments with spaces between
		# them, so that simple queries don't have to be quoted at the shell
		# level.
		#queryString = ARGV[1..-1].join(' ')
		queryString = @question

		# Parse the query string to produce a Xapian::Query object.
		qp = Xapian::QueryParser.new()
		stemmer = Xapian::Stem.new(Setting.plugin_redmine_xapian['stemming_lang'].rstrip)
		qp.stemmer = stemmer
		qp.database = database
		qp.stemming_strategy = Xapian::QueryParser::STEM_SOME
		qp.default_op = Xapian::Query::OP_OR
		query = qp.parse_query(queryString)

		logger.debug "DEBUG: Parsed query is: #{query.description()} "

		# Find the top 100 results for the query.
		enquire.query = query
		matchset = enquire.mset(0, 100)
	
		return filedocs if matchset.nil?

		# Display the results.
		#logger.debug "#{@matchset.matches_estimated()} results found."
		logger.debug "Matches 1-#{matchset.size}:\n"

		@record_info = Hash.new
		matchset.matches.each {|m|
		  #logger.debug "#{m.rank + 1}: #{m.percent}% docid=#{m.docid} [#{m.document.data}]\n"
		  #logger.debug "DEBUG: m: " + m.document.data.inspect
		  docdata=m.document.data{url}
		  dochash=Hash[*docdata.scan(/(url|sample|modtime|type|size)=\/?([^\n\]]+)/).flatten]
		  #logger.debug "hash content: " + dochash.inspect
		  if not dochash.nil? then
		    docattach = Attachment.find(:first, :conditions => [ "disk_filename = ?", dochash.fetch("url") ])
		    #logger.debug "docattach found" + docattach.inspect
		    if not docattach.nil? then
			dochash[:attachment]=docattach
			@record_info[:attach_id]=docattach[:id]
			@record_info[:doc_id]=docattach[:container_id]
			@record_info[:user_id]=docattach[:author_id]
			container=Document.find(:first, :conditions => ["id = ?", @record_info[:doc_id]]) if docattach[:container_type] == "Document"
			container=Wiki_Page.find(:first, :conditions => ["id = ?", @record_info[:doc_id]]) if docattach[:container_type] == "WikiPage"
			container=Message.find(:first, :conditions => ["id = ?", @record_info[:doc_id]]) if docattach[:container_type] == "Message"
			container=Issue.find(:first, :conditions => ["id = ?", @record_info[:doc_id]]) if docattach[:container_type] == "Issue"
			if not container.nil? then
			  if ((docattach[:container_type] == "Document") || (docattach[:container_type] == "Issue")) then
			    @record_info[:project_id]=container[:project_id]
			  elsif docattach[:container_type] == "Message"
			    board=Board.find(:first, :conditions => ["id = ?", container[:board_id]])
			    @record_info[:project_id]=board[:project_id]
			    @record_info[:board_id]=container[:board_id]
			    @record_info[:topic_id]=container[:parent_id]
			  elsif docattach[:container_type] == "WikiPage"
			    wiki=Wiki.find(:first, :conditions => ["id = ?", container[:wiki_id]])
			    @record_info[:project_id]=wiki[:project_id]
			  end
			unless container[:subject].nil?
                          @record_info[:subject]=container[:subject]
                        else
                          @record_info[:subject]=container[:title]
                        end
			  project = Project.find ( :first, :conditions => ["id =?", @record_info[:project_id]] )
			  allowed = User.current.allowed_to?("view_documents".to_sym, project )
			  if ( allowed and project_included(project[:id], projects_to_search ) )
			    #logger.debug "record_info: " + @record_info.inspect
			    filedoc = FileDoc.new (@record_info[:attach_id],
			      @record_info[:project_id],
			      @record_info[:subject],
			      dochash["sample"],
			      docattach[:created_on],
			      docattach[:container_type],
			      @record_info[:board_id],
			      @record_info[:topic_id],
			      @record_info[:doc_id],
			      @record_info[:user_id],
			      docattach[:filename] )	
			    logger.debug "DEBUG: filedoc" + filedoc.inspect
			    filedocs.push ( filedoc ) 
			    @record_info = Hash.new
			  else
			    logger.debug "DEBUG: user without permissions"
			  end
			else
			  logger.debug "DEBUG: container not found"
			end
		    end
		  end
		}
		filedocs
	end

	def project_included( project_id, projects_to_search )
		return true if projects_to_search.nil?
		found=false
		projects_to_search.each {|x| 
			found=true if x[:id] == project_id
		}
		found
	end

  	def find_optional_project
    		return true unless params[:id]
    		@project = Project.find(params[:id])
    		check_project_privacy
  		rescue ActiveRecord::RecordNotFound
    		render_404
  	end
end

