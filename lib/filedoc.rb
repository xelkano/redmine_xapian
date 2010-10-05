
class FileDoc

	def initialize (id, project_id, subject, description, created_on, container_type,
			board_id, topic_id, doc_id, user_id, filename ) 
 	  id=id
          project_id=project_id
          subject=subject                                   
          description=description                                          
          created_on=created_on
	  container_type=container_type
	  board_id=board_id
	  topic_id=topic_id
	  doc_id=doc_id
	  user_id=user_id
	  filename=filename
	end         	                          

	def event_type
		type="attachment"
	end

	def project
		project=Project.find(:first, :conditions => ["id = ?", @project_id]) 
		project[:name]
	end
	
	def event_title
		@subject= ": " +  @subject
	end

	def event_container_type
		@container_type
	end

	def event_url
		if @container_type == 'Issue'
			container_url = "/issues/"+  @doc_id.to_s
   		elsif @container_type == 'WikiPage'
			container_url = "/wiki/"+  @doc_id.to_s
   		elsif @container_type == 'Document'
			container_url = "/documents/"+ @doc_id.to_s
   		elsif @container_type == 'Message'
			container_url = "/boards/" + @board_id.to_s + "/topics/" + @topic_id.to_s + "\#message-" + @doc_id.to_s 
   		end
		container_url
	end

	def event_description
		@description
	end
	
	def event_datetime
		@created_on
	end

	def event_file_title
		@filename
	end

	def event_file_url
		file_url="/attachments/"+@id.to_s+"/"+ @filename.to_s	
	end
end


