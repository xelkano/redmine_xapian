#!/usr/bin/ruby -W0

# encoding: utf-8
# frozen_string_literal: true
#
# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Copyright © 2010    Xabier Elkano
# Copyright © 2015-22 Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'optparse'

########################################################################################################################
# BEGIN Configuration parameters
# Configure the following parameters (most of them can be configured through the command line):
########################################################################################################################

# Redmine installation directory
$redmine_root = File.expand_path('../../../../', __FILE__)

# Files location
$files = 'files'

# scriptindex binary path 
$scriptindex  = '/usr/bin/scriptindex'

# omindex binary path
$omindex = '/usr/bin/omindex'

# Directory containing Xapian databases for omindex (Attachments indexing)
$dbrootpath = File.expand_path('file_index', $redmine_root)

# Verbose output, values of 0 no verbose, greater than 0 verbose output
$verbose = 0

# Define stemmed languages to index attachments Eg. [ 'english', 'italian', 'spanish' ]
# Repository database will be always indexed in english
# Available languages are danish dutch english finnish french german german2 hungarian italian kraaij_pohlmann lovins
# norwegian porter portuguese romanian russian spanish swedish turkish:
$stem_langs	= ['english']

# Project identifiers whose repositories will be indexed eg. [ 'prj_id1', 'prj_id2' ]
# Use [] to index all projects
$projects	= []

# Temporary directory for indexing, it can be tmpfs
$tempdir	= '/tmp'

# Binaries for text conversion
$pdftotext = '/usr/bin/pdftotext -enc UTF-8'
$antiword	 = '/usr/bin/antiword'
$catdoc		 = '/usr/bin/catdoc'
$xls2csv	 = '/usr/bin/xls2csv'
$catppt		 = '/usr/bin/catppt'
$unzip		 = '/usr/bin/unzip -o'
$unrtf		 = '/usr/bin/unrtf -t text 2>/dev/null'

########################################################################################################################
# END Configuration parameters
########################################################################################################################

$environment = File.join($redmine_root, 'config/environment.rb')
$project = nil
$databasepath = nil
$repositories = nil
$onlyfiles = nil
$onlyrepos = nil
$env = 'production'
$resetlog = nil
$retryfailed = nil

MIME_TYPES = {
  'application/pdf' => 'pdf',
  'application/rtf' => 'rtf',
  'application/msword' => 'doc',
  'application/vnd.ms-excel' => 'xls',
  'application/vnd.ms-powerpoint' => 'ppt,pps',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'docx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'xlsx',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation' => 'pptx',
  'application/vnd.openxmlformats-officedocument.presentationml.slideshow' => 'ppsx',
  'application/vnd.oasis.opendocument.spreadsheet' => 'ods',
  'application/vnd.oasis.opendocument.text' => 'odt',
  'application/vnd.oasis.opendocument.presentation' => 'odp',
  'application/javascript' => 'js'
}.freeze

FORMAT_HANDLERS = {
  'pdf' => $pdftotext,
  'doc' => $catdoc,
  'xls' => $xls2csv,
  'ppt' => $catppt,
  'pps' => $catppt,
  'docx' => $unzip,
  'xlsx' => $unzip,
  'pptx' => $unzip,
  'ppsx' => $unzip,
  'ods' => $unzip,
  'odt' => $unzip,
  'odp' => $unzip,
  'rtf' => $unrtf
}.freeze

VERSION = '0.2'

optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: xapian_indexer.rb [OPTIONS...]'
  opts.separator('')
  opts.separator('Index redmine files and repositories')
  opts.separator('')  
  opts.separator('')
  opts.separator('Options:')
  opts.on('-p', '--projects a,b,c', Array,
          'Comma separated list of identifiers of projects whose repositories will be indexed') { |p| $projects = p }
  opts.on('-s', '--stemming_lang a,b,c', Array,
          'Comma separated list of stemming languages for indexing') { |s| $stem_langs = s }
  opts.on('-v', '--verbose',            'verbose') {$verbose += 1}
  opts.on('-f', '--files',              'Only index Redmine attachments') { $onlyfiles = 1 }
  opts.on('-r', '--repositories',       'Only index Redmine repositories') { $onlyrepos = 1 }
  opts.on('-e', '--environment ENV',
          'Rails ENVIRONMENT (development, testing or production), default production') { |e| $env = e}
  opts.on('-t', '--temp-dir PATH',      'Temporary directory for indexing'){ |t| $tempdir = t }  
  opts.on('-x', '--resetlog',           'Reset index log'){  $resetlog = 1 }
  opts.on('-X', '--reset-database',     'Reset database'){  $resetdatabase = 1 }
  opts.on('-V', '--version',            'show version and exit') { puts VERSION; exit}
  opts.on('-h', '--help',               'show help and exit') { puts opts; exit }
  opts.on('-R', '--retry-failed', 'retry files which omindex failed to extract text') { $retryfailed = 1 }
  opts.separator('')
  opts.separator('Examples:')
  opts.separator('  xapian_indexer.rb -f -s english,italian -v')
  opts.separator('  xapian_indexer.rb -p project_identifier -x -t /tmpfs -v')
  opts.separator('')
  opts.summary_width = 25
end

optparse.parse!

ENV['RAILS_ENV'] = $env

STATUS_SUCCESS = 1
STATUS_FAIL = -1
ADD_OR_UPDATE = 1
DELETE = 0

class IndexingError < StandardError; end

def repo_name(repository)
  repository.identifier.blank? ? 'main' : repository.identifier
end

def indexing(databasepath, project, repository)
  my_log "Fetch changesets: #{project.name} - #{repo_name(repository)}"
  repository.fetch_changesets
  repository.reload.changesets.reload
  latest_changeset = repository.changesets.first    
  revision = latest_changeset ? latest_changeset.revision : nil
  if revision
    my_log "Latest revision: #{project.name} - #{repo_name(repository)} - #{revision}"
  end
  latest_indexed = Indexinglog.where(repository_id: repository.id, status: STATUS_SUCCESS).last
  my_log "Latest indexed: #{latest_indexed.inspect}"
  begin
    indexconf = Tempfile.new('index.conf', $tempdir)
    indexconf.write "url : field boolean=Q unique=Q\n"
    indexconf.write "body : index truncate=400 field=sample\n"
    indexconf.write "date: field=date\n"
    indexconf.close
    if latest_changeset && latest_indexed
      my_log "Repository #{repo_name(repository)} indexed, indexing diff"
      indexing_diff_by_changesets(databasepath, indexconf, project, repository,
                    latest_indexed.changeset, latest_changeset)
    elsif latest_indexed
      my_log "Repository #{repo_name(repository)} indexed, indexing diff by time"
      indexing_diff_by_time(databasepath, indexconf, project, repository, latest_indexed.updated_at)
    else
      my_log "Repository #{repo_name(repository)} not indexed, indexing all"
      indexing_diff_by_time(databasepath, indexconf, project, repository, nil)
    end
    indexconf.unlink
  rescue IndexingError => e
    add_log repository, latest_changeset, STATUS_FAIL, e.message
  else
    add_log repository, latest_changeset, STATUS_SUCCESS
    my_log "Successfully indexed: " + [project.name, repo_name(repository), revision].reject(&:blank?).join(" - ")
  end
end

def supported_mime_type(entry)
  mtype = Redmine::MimeType.of(entry)    
  MIME_TYPES.include?(mtype) || Redmine::MimeType.is_type?('text', entry)
end

def add_log(repository, changeset, status, message = nil)
  log = Indexinglog.where(repository_id: repository.id).last
  if log
    log.changeset_id = changeset ? changeset.id : -1
    log.status = status
    log.message = message
    log.save!
    my_log "Log for repo #{repo_name(repository)} updated!"
  else
    log = Indexinglog.new
    log.repository = repository
    log.changeset = changeset
    log.status = status
    log.message = message
    log.save!
    my_log "New log for repo #{repo_name(repository)} saved!"
  end
end


def delete_log(repository)
  Indexinglog.where(repository_id: repository.id).delete_all
  my_log "Log for repo #{repo_name(repository)} removed!"
end

def delete_log_by_repo_id(repo_id)
  Indexinglog.where(repository_id: repo_id).delete_all
  my_log "Log for zombied repo #{repo_id} removed!"
end

def walk(databasepath, indexconf, project, repository, identifier, entries, time_last_indexed)
  return if entries.nil? || entries.size < 1
  my_log "Walk entries size: #{entries.size}"
  entries.each do |entry|
    my_log "Walking into: #{entry.lastrev&.time}"
    if entry.is_dir?
      walk databasepath, indexconf, project, repository, identifier, repository.entries(entry.path, identifier), time_last_indexed
    elsif entry.is_file? && !entry.lastrev.nil?
      if time_last_indexed.nil? || entry.lastrev.time > time_last_indexed
        add_or_update_index(databasepath, indexconf, project, repository, identifier, entry.path,
                            entry.lastrev, ADD_OR_UPDATE, MIME_TYPES[Redmine::MimeType.of(entry.path)]) if supported_mime_type(entry.path)
      end
    end
  end
end

def indexing_diff_by_time(databasepath, indexconf, project, repository, time_last_indexed)
  my_log "Indexing all: #{repo_name(repository)}"
  begin
    if repository.branches
      repository.branches.each do |branch|
        my_log "Walking in branch: #{repo_name(repository)} - #{branch}"
        walk databasepath, indexconf, project, repository, branch, repository.entries(nil, branch), time_last_indexed
      end
    else
      my_log "Walking in branch: #{repo_name(repository)} - [NOBRANCH]"
      walk databasepath, indexconf, project, repository, nil, repository.entries(nil, nil), time_last_indexed
    end
    if repository.tags
      repository.tags.each do |tag|
        my_log "Walking in tag: #{repo_name(repository)} - #{tag}"
        walk databasepath, indexconf, project, repository, tag, repository.entries(nil, tag), time_last_indexed
      end
    end
  rescue => e
    my_log "#{repo_name(repository)} encountered an error and will be skipped: #{e.message}", true
    raise IndexingError.new(e.message)
  end
end

def walkin(databasepath, indexconf, project, repository, identifier, changesets)
  my_log "Walking into #{changesets.inspect}"
  return unless changesets or changesets.size <= 0
  changesets.sort! { |a, b| a.id <=> b.id }

  actions = Hash::new
  # SCM actions
  #   * A - Add
  #   * M - Modified
  #   * R - Replaced
  #   * D - Deleted
  changesets.each do |changeset|
    my_log "Changeset changes for #{changeset.id} #{changeset.filechanges.inspect}"
    next unless changeset.filechanges
    changeset.filechanges.each do |change|        
      actions[change.path] = (change.action == 'D') ? DELETE : ADD_OR_UPDATE        
    end
  end
  return unless actions
  actions.each do |path, action|
    entry = repository.entry(path, identifier)
    if (entry && entry.is_file?) || (action == DELETE)
      if entry.nil? && (action != DELETE)
        my_log "Error indexing path: #{path.inspect}, action: #{action.inspect},
            identifier: #{identifier.inspect}", true
      end
      my_log "Entry to index #{entry.inspect}"
      lastrev = entry.lastrev if entry
      if supported_mime_type(path) || (action == DELETE)
        add_or_update_index(databasepath, indexconf, project, repository, identifier, path, lastrev, action,
                            MIME_TYPES[Redmine::MimeType.of(path)])
      end
    end
  end
end

def indexing_diff_by_changesets(databasepath, indexconf, project, repository, diff_from, diff_to)
  if diff_from.id >= diff_to.id
    my_log "Already indexed: #{repo_name(repository)} (from: #{diff_from.id} to #{diff_to.id})"
    return
  end
  my_log "Indexing diff: #{repo_name(repository)} (from: #{diff_from.id} to #{diff_to.id})"
  my_log "Indexing all: #{repo_name(repository)}"
  if repository.branches
    repository.branches.each do |branch|
      my_log "Walking in branch: #{repo_name(repository)} - #{branch}"
      walkin(databasepath, indexconf, project, repository, branch, repository.latest_changesets('', branch,
             diff_to.id - diff_from.id).select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id})
    end
  else
    my_log "Walking in branch: #{repo_name(repository)} - [NOBRANCH]"
    walkin(databasepath, indexconf, project, repository, nil, repository.latest_changesets('', nil,
           diff_to.id - diff_from.id).select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id})
  end
  if repository.tags
    repository.tags.each do |tag|
      my_log "Walking in tag: #{repo_name(repository)} - #{tag}"
      walkin(databasepath, indexconf, project, repository, tag, repository.latest_changesets('', tag,
             diff_to.id - diff_from.id).select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id})
    end
  end
end

def generate_uri(project, repository, identifier, path)
  Rails.application.routes.url_helpers.url_for controller: 'repositories', action: 'entry', id: project.identifier,
    repository_id: repository.identifier, rev: identifier, path: repository.relative_path(path), only_path: true
end

def convert_to_text(fpath, type)
  text = ""
  return text unless File.exist?(FORMAT_HANDLERS[type].split(' ').first)
  case type
  when 'pdf'    
    text = `#{FORMAT_HANDLERS[type]} #{fpath} -`
  when /(xlsx|docx|odt|pptx)/i
    system "#{$unzip} -d #{$tempdir}/temp #{fpath} > /dev/null", out: '/dev/null'
    case type
    when 'xlsx'
      fouts = ["#{$tempdir}/temp/xl/sharedStrings.xml"]
    when 'docx'
      fouts = ["#{$tempdir}/temp/word/document.xml"]
    when 'odt'
      fouts = ["#{$tempdir}/temp/content.xml"]
    when 'pptx'
      fouts = Dir["#{$tempdir}/temp/ppt/slides/*.xml"]
    end                
    begin
      fouts.each do |fout|
        text += File.read(fout) + "\n"
      end
      FileUtils.rm_rf "#{$tempdir}/temp"
    rescue => e
      my_log "Error: #{e.to_s} reading #{fouts.inspect}", true
    end
  else
    text = `#{FORMAT_HANDLERS[type]} #{fpath}`
  end
  text
end

def add_or_update_index(databasepath, indexconf, project, repository, identifier, path, lastrev, action, type)
  uri = generate_uri(project, repository, identifier, path)
  return unless uri
  text = nil
  if Redmine::MimeType.is_type?('text', path) || (%(js).include?(type))
    text = repository.cat(path, identifier)
  else
    fname = path.split('/').last.tr(' ', '_')
    bstr = repository.cat(path, identifier)
    File.open( "#{$tempdir}/#{fname}", 'wb+') do |bs|
      bs.write(bstr)
    end
    text = convert_to_text("#{$tempdir}/#{fname}", type) if File.exist?("#{$tempdir}/#{fname}") && !bstr.nil?
    File.unlink "#{$tempdir}/#{fname}"
  end
  my_log "generated uri: #{uri}"
  my_log('Mime type text') if  Redmine::MimeType.is_type?('text', path)
  my_log "Indexing: #{path}"
  begin
    itext = Tempfile.new('filetoindex.tmp', $tempdir) 
    itext.write("url=#{uri.to_s}\n")
    if action != DELETE
      sdate = lastrev.time || Time.at(0).in_time_zone
      itext.write "date=#{sdate.to_s}\n"
      body = nil
      text.force_encoding 'UTF-8'
      text.each_line do |line|        
        if body.blank? 
          itext.write "body=#{line}"
          body = 1
        else
          itext.write "=#{line}"
        end
      end      
    else
      my_log "Path: #{path} should be deleted"
    end
    itext.close    
    my_log "TEXT #{itext.path} generated"
    my_log "Index command: #{$scriptindex} -s #{$user_stem_lang} #{databasepath} #{indexconf.path} #{itext.path}"
    system_or_raise "#{$scriptindex} -s english #{databasepath} #{indexconf.path} #{itext.path}"
    itext.unlink    
    my_log 'New doc added to xapian database'
  rescue => e
    my_log e.message, true
  end
end

def my_log(text, error = false)
  if error
    $stderr.puts text
  elsif $verbose > 0    
    $stdout.puts text
  end  
end

def system_or_raise(command)
  if $verbose > 0
    raise StandardError.new("\"#{command}\" failed") unless system(command)
  else
    raise StandardError.new("\"#{command}\" failed") unless system(command, out: '/dev/null')
  end
end

def find_project(prt)        
  project = Project.active.has_module(:repository).find_by(identifier: prt)
  if project
    my_log "Project found: #{project}"
  else
    my_log "Project #{prt} not found", true
  end    
  @project = project
end

my_log "Trying to load Redmine environment <<#{$environment}>>..."

begin
 require $environment
rescue LoadError => e
  my_log e.message, true
  exit 1
end

my_log "Redmine environment [RAILS_ENV=#{$env}] correctly loaded ..."

path_to_attachment = File.join(
  Redmine::Configuration['attachments_storage_path'] || 
  File.join(Rails.root, "files")
)
puts "path_to_attachment = #{path_to_attachment}"

# Indexing files
unless $onlyrepos
  unless File.exist?($omindex)
    my_log "#{$omindex} does not exist, exiting...", true
    exit 1
  end
  $stem_langs.each do | lang |
    filespath = path_to_attachment
    unless File.directory?(filespath)
      my_log "An error while accessing #{filespath}, exiting...", true
      exit 1
    end
    databasepath = File.join($dbrootpath, lang)
    if File.directory?(databasepath) && $resetdatabase
      FileUtils.rm_rf(databasepath)
    end
    unless File.directory?(databasepath)
      my_log "#{databasepath} does not exist, creating ..."
      begin
        FileUtils.mkdir_p databasepath
      rescue => e
        my_log e.message, true
        exit 1
      end      
    end
    cmd = +"#{$omindex} -s #{lang} --db #{databasepath} #{filespath} --url / --depth-limit=0"
    cmd << ' -v' if $verbose > 0
    cmd << ' --retry-failed' if $retryfailed
    my_log cmd
    system_or_raise cmd
  end
  my_log 'Redmine files indexed'
end

# Indexing repositories
unless $onlyfiles
  unless File.exist?($scriptindex)
    my_log "#{$scriptindex} does not exist, exiting...", true
    exit 1
  end
  databasepath = File.join($dbrootpath.rstrip, 'repodb')
  if File.directory?(databasepath) && $resetdatabase
    FileUtils.rm_rf(databasepath)
  end
  unless File.directory?(databasepath)
    my_log "Db directory #{databasepath} does not exist, creating..."
    begin
      FileUtils.mkdir_p databasepath
    rescue => e
      my_log e.message, true
      exit 1
    end     
  end
  $projects = Project.active.has_module(:repository).pluck(:identifier) if $projects.blank?
  $projects.each do |identifier|
    project = Project.active.has_module(:repository).where(identifier: identifier).preload(:repository).first
    if project
      my_log "- Indexing repositories for #{project}..."
      repositories = project.repositories.select { |repository| repository.supports_cat? }
      repositories.each do |repository|
        delete_log(repository) if $resetlog
        indexing databasepath, project, repository
      end
    else
      my_log "Project identifier #{identifier} not found or repository module not enabled, ignoring..."
    end
  end
  if $resetlog
    existing_repo_ids = Repository.all.to_a.map(&:id)
    zombied_repo_ids = Indexinglog.where.not(:repository_id => existing_repo_ids).to_a.map(&:repository_id).uniq
    zombied_repo_ids.each do |zombied_repo_id|
      delete_log_by_repo_id(zombied_repo_id)
    end
  end
end

exit 0
