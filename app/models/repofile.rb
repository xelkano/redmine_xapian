
class Repofile < ActiveRecord::Base
 
  has_no_table

  #rescue_from Exception :with => :show_error

  def show_error(exception)
    Rails.logger.debug "DEBUG: exection " + exeption.inspect
  end


  def self.attr_accessor(*vars)
    @attributes ||= []
    @attributes.concat( vars )
    super
  end

  def self.attributes
    @attributes
  end

  #def initialize(attributes={})
  #  attributes && attributes.each do |name, value|
  #    send("#{name}=", value) if respond_to? name.to_sym 
  #  end
  #  Rails.logger.debug "?????"
  #end
 
  def persisted?
    false
  end


  after_create :set_variables
  belongs_to :project
  belongs_to :repository
  
  column :description,    :string
  column :created_on,   :datetime
  column :project_id,   :integer
  column :filename, 	:string
  column :repository_id, :integer
  validates_presence_of :created_on, :filename, :repository_id


  acts_as_searchable :xapianfile => "repofile",
                     :columns => ["#{table_name}.filename", "#{table_name}.description"],
#                      #:include => {:board => :project},
#                      # :project_key => 'project_id',
#                      :date_column =>  Proc.new {|o| o.event_datetime },
                       :permission => :browse_repository


  #acts_as_event :title => :filename,
 #		:url => Proc.new {|o| {:controller => 'repositories', :action => 'changes', :id => o.project_id, 
#			:repository_id => o.repository_id, :rev => nil, :path => o.filename} },
#	        :type => Proc.new {|o| o.repo_type }
   	#	:created_on =>  Proc.new {|o| o.file_timestamp }
  attr_accessor :description 
  attr_accessor :created_on
  attr_accessor :project_id
  attr_accessor :filename
  attr_accessor :repository_id

  def event_title
    self[:filename]
  end

  def event_date
    Rails.logger.debug "DEBUG: date call"
    #self[:created_on].to_date
    Time.now.to_date
  end 

  def event_datetime
    Rails.logger.debug "DEBUG: datetime call"
    @created_on = self[:created_on]
    self[:created_on]
  end

  def event_url
    {:controller => 'repositories', :action => 'changes', :id => self[:project_id], 
	:repository_id => self[:repository_id], :rev => nil, :path => self[:filename]} 
  end

  def event_description
    self[:description]
  end
	
  def set_variables
    Rails.logger.debug "DEBUG: repofile after_initialize #{self.read_attribute(filename)}"
    @filename = self.read_attribute(filename)
    @project_id = self.read_attribute(project_id)
    @descrtiption = self.read_attribute(description)
    @repository_id = self.read_attribute(repository_id) 
    @created_on = self.read_attribute(created_on)
    Rails.logger.debug "DEBUG: repofile after_initialize EDN"
  end

  def event_type
    self.repo_type
  end

  def repo_type
    self.repository.type.split('::')[1].downcase
  end 

  def file_timestamp
    Rails.logger.debug "DEBUG: file_timestamp filename: #{self.read_attribute(filename)}"
    repositoryfile = File.join(Rails.root, "files", "repos", project.name, self.repository.identifier, self.read_attribute(filename) )
    Rails.logger.debug "DEBUG: file_timestamp #{repositoryfile}"
    Rails.logger.debug "DEBUG: File mtime: #{File.new(repositoryfile).mtime}"
    self.created_on=File.new(repositoryfile).mtime
  end

end
