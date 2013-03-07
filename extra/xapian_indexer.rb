#!/usr/bin/ruby -W0
# encoding: UTF-8


################################################################################################
# BEGIN Configuration parameters
# Configure the following parameters (most of them can be configured through the command line):
################################################################################################

# Redmine installation directory
$redmine_root = "/var/www/redmine"

# scriptindex binary path 
$scriptindex  = "/usr/bin/scriptindex"

# omindex binary path
$omindex      = "/usr/bin/omindex"

# Directory containing xapian databases for omindex (Attachments indexing)
$dbrootpath   = "/var/www/xapian-index"

# Verbose output, values of 0 no verbose, greater than 0 verbose output
$verbose      = 0

# Define stemmed languages to index attachments Ej [ 'english', 'italian', 'spanish' ]
# Repository database will be always indexed in english
# Available languages are danish dutch english finnish french german german2 hungarian italian kraaij_pohlmann lovins norwegian porter portuguese romanian russian spanish swedish turkish:  
$stem_langs	= ['english', 'spanish']

#Project identifiers that will be indexed Ej [ 'prj_id1', 'prj_id2' ]
$projects	= [ 'prj_id1', 'prj_id2' ]

################################################################################################
# END Configuration parameters
################################################################################################

$environment  = File.join($redmine_root, "config/environment.rb")
$project=nil
$databasepath=nil
$repositories=nil
$onlyfiles=nil
$onlyrepos=nil
$env='production'


require 'optparse'


VERSION = "0.1"
SUPPORTED_SCM = %w( Subversion Darcs Mercurial Bazaar Git Filesystem )


optparse = OptionParser.new do |opts|
  opts.banner = "Usage: xapian_indexer.rb [OPTIONS...]"
  opts.separator("")
  opts.separator("Index redmine files and repositories")
  opts.separator("")
  #opts.on("-k", "--key KEY",           "use KEY as the Redmine repository key") { |k| $key = k}
  opts.separator("")
  opts.separator("Options:")
  opts.on("-p", "--projects a,b,c",Array,     "Comma separated list of projects to index") { |p| $projects=p }
  opts.on("-s", "--stemming_lang a,b,c",Array,"Comma separated list of stemming languages for indexing") { |s| $stem_langs=s }
  #opts.on("-t", "--test",              "only show what should be done") {$test = true}
  #opts.on("-f", "--force",             "force reindex") {$force = true}
  opts.on("-v", "--verbose",            "verbose") {$verbose += 1}
  opts.on("-f", "--files",              "Only index Redmine attachments") {$onlyfiles = 1}
  opts.on("-r", "--repositories",       "Only index Redmine repositories") {$onlyrepos = 1}
  opts.on("-e", "--environment",        "Rails ENVIRONMENT (development, testing or production), default production") {|e| $env = e}
  opts.on("-V", "--version",            "show version and exit") {puts VERSION; exit}
  opts.on("-h", "--help",               "show help and exit") {puts opts; exit }
  #opts.on("-q", "--quiet",             "no log") {$quiet = true}
  opts.separator("")
  opts.separator("Example:")
  opts.separator("  xapian_indexer.rb -f -s english,italian -v")
  opts.separator("")

  opts.summary_width = 25
end
optparse.parse!

ENV['RAILS_ENV'] = $env

STATUS_SUCCESS = 1
STATUS_FAIL = -1
    
ADD_OR_UPDATE = 1
DELETE = 0

MAIN_REPOSITORY_IDENTIFIER = 'main'



class IndexingError < StandardError; end
    

#@rwdb = Xapian::WritableDatabase.new(databasepath, Xapian::DB_CREATE_OR_OVERWRITE)          

     
def indexing(repository)
    $repository=repository
    Rails.logger.info("Fetch changesets: %s - %s" % [$project.name,(repository.identifier or MAIN_REPOSITORY_IDENTIFIER)])
    log("- Fetch changesets: #{$project.name} - #{$repository.identifier}", :level=>1)
    $repository.fetch_changesets
    $repository.reload.changesets.reload

    latest_changeset = $repository.changesets.find(:first)
    return if not latest_changeset

    Rails.logger.debug("Latest revision: %s - %s - %s" % [
      $project.name,
      ($repository.identifier or MAIN_REPOSITORY_IDENTIFIER),
      latest_changeset.revision])
    #latest_indexed = Indexinglog.find_by_repository_id_and_status( repository.id, STATUS_SUCCESS, :first)
    latest_indexed = Indexinglog.where("repository_id=#{$repository.id} AND status=#{STATUS_SUCCESS}").last
    #latest_indexed = nil
    Rails.logger.debug "Debug latest_indexed " + latest_indexed.inspect
    begin
      $indexconf = Tempfile.new( "index.conf", "/tmp" )
      $indexconf.write "url : field boolean=Q unique=Q\n"
      $indexconf.write "body : index truncate=400 field=sample\n"
      $indexconf.write "date: field=date\n"
      $indexconf.close
      if not latest_indexed
        Rails.logger.debug "DEBUG:  repo #{$repository.identifier} not indexed, indexing all"
        log("\t>repo #{$repository.identifier} not indexed, indexing all", :level=>1)
        indexing_all($repository)
      else
        Rails.logger.debug "DEBUG:  repo #{$repository.identifier} indexed, indexing diff"
        log("\t>repo #{$repository.identifier} already indexed, indexing only diff", :level=>1)
        indexing_diff($repository, latest_indexed.changeset, latest_changeset)
      end
      $indexconf.unlink
    rescue IndexingError => e
      add_log($repository, latest_changeset, STATUS_FAIL, e.message)
    else
      add_log($repository, latest_changeset, STATUS_SUCCESS)
      Rails.logger.info("Successfully indexed: %s - %s - %s" % [
        $project.name,
        ($repository.identifier or MAIN_REPOSITORY_IDENTIFIER),
        latest_changeset.revision])
    end
end

      

def add_log(repository, changeset, status, message=nil)
  log = Indexinglog.where("repository_id=#{repository.id}").last
  if not log
    log = Indexinglog.new
    log.repository = repository
    log.changeset = changeset
    log.status = status
    log.message = message if message
    log.save!
    Rails.logger.info("New log for repo %s saved!"% [repository.identifier] )
    log("\t>New log for repo #{repository.identifier} saved!", :level=>1)
  else
    log.changeset_id=changeset.id
    log.status=status
    log.message = message if message
    log.save!
    Rails.logger.info("Log for repo %s updated!"% [repository.identifier] )
    log("\t>Log for repo #{repository.identifier} updated!", :level=>1)
  end
end

def indexing_all(repository)
  def walk(repository, identifier, entries)
    Rails.logger.debug "DEBUG: walk entries size: " + entries.size.inspect
    return if entries.size < 1
    entries.each do |entry|
      Rails.logger.debug "DEBUG: walking into: " + entry.lastrev.time.inspect
      if entry.is_dir?
        walk(repository, identifier, repository.entries(entry.path, identifier))
      elsif entry.is_file?
        add_or_update_index(repository, identifier, entry, ADD_OR_UPDATE ) if Redmine::MimeType.is_type?('text', entry.path)
      end
    end
  end

  Rails.logger.info("Indexing all: %s" % [
    (repository.identifier or MAIN_REPOSITORY_IDENTIFIER)])
  if repository.branches
    repository.branches.each do |branch|
      Rails.logger.debug("Walking in branch: %s - %s" % [
        (repository.identifier or MAIN_REPOSITORY_IDENTIFIER), branch])
      walk(repository, branch, repository.entries(nil, branch))
    end
  else
    Rails.logger.debug("Walking in branch: %s - %s" % [
      (repository.identifier or MAIN_REPOSITORY_IDENTIFIER), "[NOBRANCH]"])
    walk(repository, nil, repository.entries(nil, nil))
  end
  if repository.tags
    repository.tags.each do |tag|
      Rails.logger.debug("Walking in tag: %s - %s" % [
        (repository.identifier or MAIN_REPOSITORY_IDENTIFIER), tag])
      walk(repository, tag, repository.entries(nil, tag))
    end
  end
end

def indexing_diff(repository, diff_from, diff_to)
  def walk(repository, identifier, changesets)
    Rails.logger.debug "DEBUG: walking into " + changesets.inspect     
    return if not changesets or changesets.size <= 0
    changesets.sort! { |a, b| a.id <=> b.id }

    actions = Hash::new
    # SCM actions
    #   * A - Add
    #   * M - Modified
    #   * R - Replaced
    #   * D - Deleted
    changesets.each do |changeset|
      Rails.logger.debug "DEBUG: changeset changes for #{changeset.id} " + changeset.filechanges.inspect
      next unless changeset.filechanges
      changeset.filechanges.each do |change|
	#log( "change.path: #{change.path.inspect}", :level=>1 ) if change.path.include? "/trunk/Sites/divendo/System/cron/api/clasificado"
        if change.action == 'D'
          actions[change.path] = DELETE
	  #entry = repository.entry(change.path, identifier)
	  #add_or_update_index(repository, identifier, entry, DELETE )
        else
          actions[change.path] = ADD_OR_UPDATE
	  #entry = repository.entry(change.path, identifier)
	  #add_or_update_index(repository, identifier, entry, ADD_OR_UPDATE )
        end
      end
    end
    return unless actions
    actions.each do |path, action|
      entry = repository.entry(path, identifier)
      log("Error indexing path: #{path.inspect}, action: #{action.inspect}, identifier: #{identifier.inspect}", :level=>1) if entry.nil?
      Rails.logger.debug "DEBUG: entry to index " + entry.inspect
      add_or_update_index(repository, identifier, entry, action ) unless entry.nil?
    end
  end

  if diff_from.id >= diff_to.id
    Rails.logger.info("Already indexed: %s (from: %s to %s)" % [
            (repository.identifier or MAIN_REPOSITORY_IDENTIFIER),diff_from.id, diff_to.id])
    log("\t>Already indexed: #{repository.identifier} (from #{diff_from.id} to #{diff_to.id})", :level=>1)
    return
  end

  Rails.logger.info("Indexing diff: %s (from: %s to %s)" % [
          (repository.identifier or MAIN_REPOSITORY_IDENTIFIER),diff_from.id, diff_to.id])
  Rails.logger.info("Indexing all: %s" % [
          (repository.identifier or MAIN_REPOSITORY_IDENTIFIER)])
  if repository.branches
    repository.branches.each do |branch|
      Rails.logger.debug("Walking in branch: %s - %s" % [(repository.identifier or MAIN_REPOSITORY_IDENTIFIER), branch])
      walk(repository, branch, repository.latest_changesets("", branch, diff_to.id - diff_from.id)\
               .select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id})

    end
  else
    Rails.logger.debug("Walking in branch: %s - %s" % [(repository.identifier or MAIN_REPOSITORY_IDENTIFIER), "[NOBRANCH]"])
    walk(repository, nil, repository.latest_changesets("", nil, diff_to.id - diff_from.id)\
             .select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id})
  end
  if repository.tags
    repository.tags.each do |tag|
      Rails.logger.debug("Walking in tag: %s - %s" % [(repository.identifier or MAIN_REPOSITORY_IDENTIFIER), tag])
      walk(repository, tag, repository.latest_changesets("", tag, diff_to.id - diff_from.id)\
               .select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id})
    end
  end
end

def generate_uri(repository, identifier, path)
  return url_for(:controller => 'repositories',
                    :action => 'entry',
                    :id => $project,
                    :repository_id => repository.identifier,
                    :rev => identifier,
                    :path => repository.relative_path(path),
                    :only_path => true)
end

def print_and_flush(str)
  print str
  $stdout.flush
end

def add_or_update_index(repository, identifier, entry, action)
  uri = generate_uri(repository, identifier, entry.path)
  return unless uri
  text = repository.cat(entry.path, identifier)
  #return delete_doc(uri) unless text
  return  unless text
  Rails.logger.debug "generated uri: " + uri.inspect
  #log("\t>Generated uri: #{uri.inspect}", :level=>1)
  Rails.logger.debug "Mime type text" if  Redmine::MimeType.is_type?('text', entry.path)
  #print "\t>rev: " + identifier.inspect
  log("\t>Indexing: #{entry.path}", :level=>1)
  begin
    itext = Tempfile.new( "filetoindex.tmp", "/tmp" )       
    itext.write("url=#{uri.to_s}\n")
    if action != DELETE then
      itext.write("date=#{entry.lastrev.time.to_s}\n")
      body=nil
      text.force_encoding('UTF-8')
      text.each_line do |line|
        #Rails.logger.debug "inspecting line: " + line.inspect
        if body.blank? 
          itext.write("body=#{line}")
          body=1
        else
          itext.write("=#{line}")
        end
      end
      #print_and_flush "A" if $verbose
    else
      #print_and_flush "D" if $verbose
      Rails.logger.debug "DEBUG path: %s should be deleted" % [path]
    end
    itext.close
    Rails.logger.debug "TEXT #{itext.path} generated " 
    #@rwdb.close #Closing because of use of scriptindex
    Rails.logger.debug "DEBUG index cmd: #{$scriptindex} -s #{$user_stem_lang} #{$databasepath} #{$indexconf.path} #{itext.path}"
    system_or_raise("#{$scriptindex} -s english #{$databasepath} #{$indexconf.path} #{itext.path} " )
    itext.unlink
    Rails.logger.info ("New doc added to xapian database")
    rescue Exception => e  
      Rails.logger.error("ERROR text not indexed beacause an error #{e.to_s}")
  end
end
 


#include RepositoryIndexer

def log(text, options={})
  level = options[:level] || 0
  puts text unless $quiet or level > $verbose
  exit 1 if options[:exit]
end

def system_or_raise(command)
  raise "\"#{command}\" failed" unless system command ,:out=>'/dev/null'
end

def find_project(prt)
    puts "find project for #{prt}"
    scope = Project.active.has_module(:repository)
    project = nil
    project = scope.find_by_identifier(prt)
    Rails.logger.debug "DEBUG: project found: #{project.inspect}"
    raise ActiveRecord::RecordNotFound unless project
    rescue ActiveRecord::RecordNotFound
      log("- ERROR project #{prt} not found", :level => 1)
    @project=project
end

def create_dir(path)
  $rdo=0
  begin
    Dir.mkdir(path)
    sleep 1
  rescue SystemCallError
    $rdo=1
  end
  $rdo
end

log("- Trying to load Redmine environment <<#{$environment}>>...", :level => 1)

begin
 require $environment
rescue LoadError
  puts "\n\tRedmine #{$environment} cannot be loaded!! Be sure the redmine installation directory is correct!\n"
  puts "\tEdit script and correct path\n\n"
  exit 1
end

include Rails.application.routes.url_helpers

log("- Redmine environment [RAILS_ENV=#{$env}] correctly loaded ...", :level => 1) 


if $test
  log("- Running in test mode ...")
end


# Indexing files
if not $onlyrepos then
  if not File.exist?($omindex) then
    log("- ERROR! #{$omindex} does not exist, exiting...")
    exit 1
  end
  $stem_langs.each do | lang |
    $filespath=File.join($redmine_root, "files")
    if not File.directory?($filespath) then
      log("- ERROR accessing #{$filespath}, exiting ...")
      exit 1
    end
    dbpath=File.join($dbrootpath,lang)
    if not File.directory?(dbpath)
      log("- ERROR! #{dbpath} does not exist, creating ...")
      if not create_dir(dbpath) then
        log("- ERROR! #{dbpath} can not be created!, exiting ...")
        exit 1
      end
    end
    log("- Indexing files under #{$filespath} with omindex stemming in #{lang} ...", :level=>1)
    system_or_raise ("#{$omindex} -s #{lang} --db #{dbpath} #{$filespath} --url / > /dev/null")
  end
  log("- Redmine files indexed ...", :level=>1)
end

# Indexing repositories
if not $onlyfiles then
  if not File.exist?($scriptindex) then
    log("- ERROR! #{$scriptindex} does not exist, exiting...")
    exit 1
  end
  $databasepath = File.join( $dbrootpath.rstrip, "repodb" )
  if not File.directory?($databasepath)
    log("Db directory #{$databasepath} does not exist, creating...")
    begin
      Dir.mkdir($databasepath)
      sleep 1
    rescue SystemCallError
      log("ERROR! #{$databasepath} can not be created!, exiting ...")
      exit 1
    end
  end
  $project=nil
  $projects.each do |proj|
    begin
      scope = Project.active.has_module(:repository)
      $project = scope.find_by_identifier(proj)
      raise ActiveRecord::RecordNotFound unless $project
      log("- Indexing repositories for #{$project.name} ...", :level=>1)
      $repositories = $project.repositories.select { |repository| repository.supports_cat? }
      $repositories.each do |repository|
	if repository.identifier.nil? then
	  log("\t>Ignoring repo id #{repository.id}, repo has undefined identifier", :level=>1)
	else
          indexing(repository)
	end
      end
    rescue ActiveRecord::RecordNotFound
      log("- ERROR project identifier #{proj} not found, ignoring...", :level => 1)
      Rails.logger.error "Project identifier #{proj} not found "
    end
  end
end

exit 0
