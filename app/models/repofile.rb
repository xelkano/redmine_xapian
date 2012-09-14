
class Repofile < ActiveRecord::Base


  has_no_table
  belongs_to :project
  column :description,    :string
  column :created_on,   :datetime
  column :project_id,   :integer
  column :filename, 	:string
  column :repository_id, :integer
  validates_presence_of :created_on, :filename, :repository_id

  after_create do
    logger.info "DEBUG: Called after_initialize"
    self.created_on = "0000-00-00 00:00:00"
    self.description= ""
    self.project_id = 0
  end

  acts_as_event :title => :filename,
                #:url => "http://prered.hostinet.com/projects/test/repository/entry/"+:filename,
 		:url => Proc.new {|o| {:controller => 'repositories', :action => 'show', :id => o.project_id, 
			:repository_id => o.repository_id, :rev => nil, :path => o.filename} },
	        :type => "repofile"
		#:datetime => self.read_attribute(:created_on)		
		#:datetime => @created_on
  attr_accessor :description 
  attr_accessor :created_on
  attr_accessor :project_id
  attr_accessor :filename
  attr_accessor :repository_id



  def to_hash
    Hash[instance_variables.map { |var| [var[1..-1].to_sym, instance_variable_get(var)] }]
  end

  def container_url
        container_url
  end
  def container_name
        container_name
  end
  def container_type
        container_type
  end

  #def event_datetime
 #   begin
 #     #Rails.logger.debug "DEBUG: tableless not loaded" + DateTime.parse(self.read_attribute(:created_on)).inspect
 #     #DateTime.parse(self.read_attribute(:created_on))
 #     self.read_attribute(:created_on)
 #   rescue
 #     Rails.logger.debug "DEBUG: error en event_datetime"
 #     Rails.logger.debug "DEBUG: created_on"  + self.read_attribute(:created_on).inspect
 #   end
 # end

 # def event_type
 #   "repofile"
 # end


end
