
begin
    require 'xapian'
    $xapian_bindings_available = true
rescue LoadError
    Rails.logger.notice "No Ruby bindings for Xapian installed"
    $xapian_bindings_available = false
end


module XapianSearch
  
  @@numattach=0
  
  def XapianSearch.search_attachments(tokens, limit_options, offset, projects_to_search, all_words )
		xpattachments = Array.new
		return xpattachments unless Setting.plugin_redmine_xapian['enable'] == "true"
		database = Xapian::Database.new(Setting.plugin_redmine_xapian['index_database'].rstrip)

		# Start an enquire session.
		enquire = Xapian::Enquire.new(database)

		# Combine the rest of the command line arguments with spaces between
		# them, so that simple queries don't have to be quoted at the shell
		# level.
		#queryString = ARGV[1..-1].join(' ')
		queryString = tokens.join(' ')
		# Parse the query string to produce a Xapian::Query object.
		qp = Xapian::QueryParser.new()
		stemmer = Xapian::Stem.new(Setting.plugin_redmine_xapian['stemming_lang'].rstrip)
		qp.stemmer = stemmer
		qp.database = database
		case Setting.plugin_redmine_xapian['stemming_strategy'].rstrip
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
	
		return xpattachments if matchset.nil?

		# Display the results.
		#logger.debug "#{@matchset.matches_estimated()} results found."
		Rails.logger.debug "DEBUG: Matches 1-#{matchset.size}:\n"

		matchset.matches.each {|m|
		  #logger.debug "#{m.rank + 1}: #{m.percent}% docid=#{m.docid} [#{m.document.data}]\n"
		  #logger.debug "DEBUG: m: " + m.document.data.inspect
		  docdata=m.document.data{url}
		  dochash=Hash[*docdata.scan(/(url|sample|modtime|type|size)=\/?([^\n\]]+)/).flatten]
		  if not dochash.nil? then
		    find_conditions =  Attachment.merge_conditions (limit_options[:conditions],  :disk_filename => dochash.fetch('url') )
		    docattach=Attachment.find (:first, :conditions =>  find_conditions  )
		    #logger.debug "docattach found" + docattach.inspect
		    if not docattach.nil? then
		      if not docattach.container.nil? then
		        allowed = User.current.allowed_to?("view_documents".to_sym, docattach.container.project )
		        if ( allowed and project_included(docattach.container.project.id, projects_to_search ) )
			  docattach[:description]=dochash["sample"]
			  xpattachments.push ( docattach )
		        else
		 	  Rails.logger.debug "DEBUG: user without permissions"
		        end
		      end
		    end
		  end
		}	
		@@numattach=xpattachments.size if offset.nil?
		xpattachments=xpattachments.sort_by{|x| x[:created_on] }
		[xpattachments, @@numattach]
	end


	def XapianSearch.project_included( project_id, projects_to_search )
		return true if projects_to_search.nil?
		found=false
		projects_to_search.each {|x| 
			found=true if x[:id] == project_id
		}
		found
	end

end
