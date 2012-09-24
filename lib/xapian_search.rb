

module XapianSearch
  
  @@numattach=0
  
  def XapianSearch.search_attachments(tokens, limit_options, offset, projects_to_search, all_words, user_stem_lang, user_stem_strategy )
    xpattachments = Array.new
    return [xpattachments,0] unless Setting.plugin_redmine_xapian['enable'] == "true"
    Rails.logger.debug "DEBUG: global settings dump" + Setting.plugin_redmine_xapian.inspect
    Rails.logger.debug "DEBUG: user_stem_lang: " + user_stem_lang.inspect
    Rails.logger.debug "DEBUG: user_stem_strategy: " + user_stem_strategy.inspect
    Rails.logger.debug "DEBUG: databasepath: " + getDatabasePath(user_stem_lang)
    databasepath = getDatabasePath(user_stem_lang)

    begin
      database = Xapian::Database.new(databasepath)
    rescue => error
      raise databasepath
      return [xpattachments,0]
    end

    # Start an enquire session.
		
    enquire = Xapian::Enquire.new(database)

    # Combine the rest of the command line arguments with spaces between
    # them, so that simple queries don't have to be quoted at the shell
    # level.
    #queryString = ARGV[1..-1].join(' ')
    queryString = tokens.join(' ')
    # Parse the query string to produce a Xapian::Query object.
    qp = Xapian::QueryParser.new()
    stemmer = Xapian::Stem.new(user_stem_lang)
    qp.stemmer = stemmer
    qp.database = database
    case @user_stem_strategy
      when "STEM_NONE" then qp.stemming_strategy = Xapian::QueryParser::STEM_NONE
      when "STEM_SOME" then qp.stemming_strategy = Xapian::QueryParser::STEM_SOME
      when "STEM_ALL" then qp.stemming_strategy = Xapian::QueryParser::STEM_ALL
    end
    if all_words
      qp.default_op = Xapian::Query::OP_AND
    else	
      qp.default_op = Xapian::Query::OP_OR
    end
    query = qp.parse_query(queryString)
    Rails.logger.debug "DEBUG queryString is: #{queryString}"
    Rails.logger.debug "DEBUG: Parsed query is: #{query.description()} "

    # Find the top 100 results for the query.
    enquire.query = query
    matchset = enquire.mset(0, 1000)
	
    return [xpattachments,0] if matchset.nil?

    # Display the results.
    #logger.debug "#{@matchset.matches_estimated()} results found."
    Rails.logger.debug "DEBUG: Matches 1-#{matchset.size}:\n"

    matchset.matches.each {|m|
      #Rails.logger.debug "#{m.rank + 1}: #{m.percent}% docid=#{m.docid} [#{m.document.data}]\n"
      Rails.logger.debug "DEBUG: m: " + m.document.data.inspect
      docdata=m.document.data{url}
      dochash=Hash[*docdata.scan(/(url|sample|modtime|type|size)=\/?([^\n\]]+)/).flatten]
      if not dochash.nil? then
        Rails.logger.debug "DEBUG: dochash not nil.. " + dochash.fetch('url').to_s
	Rails.logger.debug "DEBUG: limit_conditions " + limit_options[:limit].inspect
	if dochash["url"].to_s =~ /^repos\// then
	  # repo file
	  Rails.logger.debug "DEBUG: repo file: " + dochash.fetch('url').inspect
	  dochash2=Hash[ [:project_identifier, :repo_identifier, :file ].zip(dochash.fetch('url').split('/',4).drop(1)) ]
	  project=Project.where(:identifier => dochash2[:project_identifier]).first
	  repository=Repository.where( :project_id=>project.id, :identifier=>dochash2[:repo_identifier] ).first
	  Rails.logger.debug "DEBUG: repository found " + repository.inspect
	  if not repository.nil? then
            allowed = User.current.allowed_to?(:browse_repository, repository.project)
	    Rails.logger.debug "DEBUG: allowed: " + allowed.inspect + " to project: " + repository.project.inspect
            if ( allowed and project_included( project.id, projects_to_search ) )
              docattach=Repofile.new( :filename=>dochash2[:file], :created_on=>"2012-08-23 22:34:50", :project_id=>project.id, 
			:repository_id=>repository.id)
	      #docattach.attributes( :description=>dochash["sample"], :created_on=>"2012-08-23 22:34:50")
	      Rails.logger.debug "DEBUG: push attach" + docattach.inspect
              docattach[:description]=dochash["sample"]
	      docattach[:created_on]="2012-08-23 22:34:50"
	      docattach[:project_id]=project.id
	      docattach[:repository_id]=repository.id
	      docattach[:filename]=dochash2[:file]
	      
  	      #load 'acts_as_event.rb'
	      docattach[:project_id]=project.id
	      Rails.logger.debug "DEBUG: attach event_datetime" + docattach.event_datetime.inspect
	      Rails.logger.debug "DEBUG: ok created"
	      Rails.logger.debug "DEBUG: push attach" + docattach.inspect
              xpattachments.push(docattach)
            else
              Rails.logger.debug "DEBUG: user without permissions"
            end
          end
	else	
	  # attach file		
	  docattach=Attachment.where( :disk_filename => dochash.fetch('url') ).first
	  Rails.logger.debug "DEBUG: attach event_datetime" + docattach.event_datetime.inspect
	  Rails.logger.debug "DEBUG: attach project" + docattach.project.inspect
	  if not docattach.nil? then
	    Rails.logger.debug "DEBUG: docattach not nil..:  " + docattach.inspect 
	    if docattach["container_type"] == "Article" and not Redmine::Search.available_search_types.include?("articles")
              Rails.logger.debug "DEBUG: Knowledgebase plugin is not installed.."
            elsif not docattach.container.nil? then
	      Rails.logger.debug "DEBUG: adding attach.. " 
	      allowed =  User.current.allowed_to?("view_documents".to_sym, docattach.container.project)  ||  docattach.container_type == "Article"
	      if ( allowed and project_included(docattach.container.project.id, projects_to_search ) )
	        docattach[:description]=dochash["sample"]
	        xpattachments.push(docattach)
	      else
	        Rails.logger.debug "DEBUG: user without permissions"
	      end
	    end
          end
	end
      end
    }	
    Rails.logger.debug "DEBUG: xapian searched"
    @@numattach=xpattachments.size if offset.nil?
    xpattachments=xpattachments.sort_by{|x| x[:created_on] }

    if RUBY_VERSION >= "1.9"
      xpattachments = xpattachments.map do |attachment|
        attachment[:description].force_encoding('UTF-8')
        attachment
      end
    end
    [xpattachments, @@numattach]
end


  def XapianSearch.project_included( project_id, projects_to_search )
	Rails.logger.debug "DEBUG: project id: " + project_id.inspect
	Rails.logger.debug "DEBUG: projects to search: " + projects_to_search.inspect
    return true if projects_to_search.nil?
    found=false
    projects_to_search.each {|x| 
      found=true if x[:id] == project_id
    }
    found
  end

  def XapianSearch.getDatabasePath(user_stem_lang)
    return Setting.plugin_redmine_xapian['index_database'].rstrip + '/' + user_stem_lang
  end

end