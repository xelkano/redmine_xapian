module RedmineXapian
  module SearchStrategies
    module XapianSearch
      def search_attachments(tokens, limit_options, offset, projects_to_search, all_words, user_stem_lang, user_stem_strategy )
        xpattachments = Array.new
        return [xpattachments,0] unless Setting.plugin_redmine_xapian['enable'] == "true"
        Rails.logger.debug "DEBUG: global settings dump" + Setting.plugin_redmine_xapian.inspect
        Rails.logger.debug "DEBUG: user_stem_lang: " + user_stem_lang.inspect
        Rails.logger.debug "DEBUG: user_stem_strategy: " + user_stem_strategy.inspect
        Rails.logger.debug "DEBUG: databasepath: " + get_database_path(user_stem_lang)
        databasepath = get_database_path(user_stem_lang)

        begin
          database = Xapian::Database.new(databasepath)
        rescue => error
          raise databasepath
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

        matchset.matches.each do |m|
          #Rails.logger.debug "#{m.rank + 1}: #{m.percent}% docid=#{m.docid} [#{m.document.data}]\n"
          Rails.logger.debug "DEBUG: m: " + m.document.data.inspect
          docdata = m.document.data{url}
          dochash = Hash[*docdata.scan(/(url|sample|modtime|type|size)=\/?([^\n\]]+)/).flatten]
          if dochash
            Rails.logger.debug "DEBUG: dochash not nil.. " + dochash.fetch('url').to_s
            Rails.logger.debug "DEBUG: limit_conditions " + limit_options[:limit].inspect
            if dochash["url"].to_s =~ /^repos\// then
              if repo_file = process_repo_file(projects_to_search, dochash)
                xpattachments << repo_file
              end
            else
              if attachment = process_attachment(projects_to_search, dochash)
                xpattachments << attachment
              end
            end
          end
        end
        Rails.logger.debug "DEBUG: xapian searched"
        xpattachments = xpattachments.sort_by{|x| x[:created_on] }

        if RUBY_VERSION >= "1.9"
          xpattachments = xpattachments.each do |attachment|
            attachment[:description].force_encoding('UTF-8')
          end
        end

        [xpattachments, xpattachments.size]
      end
    private

      def process_attachment(projects_to_search, dochash)
        docattach = Attachment.where( :disk_filename => dochash.fetch('url') ).first
        Rails.logger.debug "DEBUG: attach event_datetime" + docattach.event_datetime.inspect
        Rails.logger.debug "DEBUG: attach project" + docattach.project.inspect
        if docattach
          Rails.logger.debug "DEBUG: docattach not nil..:  " + docattach.inspect
          if docattach["container_type"] == "Article" && !Redmine::Search.available_search_types.include?("articles")
            Rails.logger.debug "DEBUG: Knowledgebase plugin is not installed.."
          elsif docattach.container
            Rails.logger.debug "DEBUG: adding attach.. "

            user = User.current
            project = docattach.container.project
            container_type = docattach["container_type"]
            container_permission = SearchStrategies::ContainerTypeHelper.to_permission(container_type)
            can_view_container = user.allowed_to?(container_permission, project)

            allowed = case container_type
            when "Article"
              true
            when "Issue"
              can_view_issue = Issue.find_by_id(docattach[:container_id]).visible?
              allowed = can_view_container && can_view_issue
            else
              allowed = can_view_container
            end

            if allowed && project_included(docattach.container.project.id, projects_to_search)
              docattach[:description] = dochash["sample"]
              docattach
            else
              Rails.logger.debug "DEBUG: user without permissions"
              nil
            end
          end
        end
      end

      def process_repo_file(projects_to_search, dochash)
        Rails.logger.debug "DEBUG: repo file: " + dochash.fetch('url').inspect
        dochash2=Hash[ [:project_identifier, :repo_identifier, :file ].zip(dochash.fetch('url').split('/',4).drop(1)) ]
        project=Project.where(:identifier => dochash2[:project_identifier]).first
        repository=Repository.where( :project_id=>project.id, :identifier=>dochash2[:repo_identifier] ).first
        Rails.logger.debug "DEBUG: repository found " + repository.inspect
        if repository
          allowed = User.current.allowed_to?(:browse_repository, repository.project)
          Rails.logger.debug "DEBUG: allowed: " + allowed.inspect + " to project: " + repository.project.inspect
          if ( allowed and project_included( project.id, projects_to_search ) )
            docattach=Repofile.new(:filename=>dochash2[:file], :created_on=>"2012-08-23 22:34:50", :project_id=>project.id,
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
            docattach
          else
            Rails.logger.debug "DEBUG: user without permissions"
            nil
          end
        end
      end

      def project_included( project_id, projects_to_search )
        Rails.logger.debug "DEBUG: project id: " + project_id.inspect
        Rails.logger.debug "DEBUG: projects to search: " + projects_to_search.inspect
        return true if projects_to_search.nil?
        projects_to_search.any? { |x| x[:id] == project_id }
      end

      def get_database_path(user_stem_lang)
        File.join(
          Setting.plugin_redmine_xapian['index_database'].rstrip,
          user_stem_lang
        )
      end
    end
  end
end
