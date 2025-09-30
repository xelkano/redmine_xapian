#!/usr/bin/ruby -W0

# frozen_string_literal: true

# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Xabier Elkano, Karel Pičman <karel.picman@kontron.com>
#
# This file is part of Redmine Xapian plugin.
#
# Redmine Xapian plugin is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# Redmine Xapian plugin is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
# the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with Redmine Xapian plugin. If not, see
# <https://www.gnu.org/licenses/>.

require 'optparse'

########################################################################################################################
# BEGIN Configuration parameters
# Configure the following parameters (most of them can be configured through the command line):
########################################################################################################################

# Redmine installation directory
REDMINE_ROOT = File.expand_path('../../../', __dir__)

# Files location
FILES = 'files'

# scriptindex binary path
SCRIPTINDEX = '/usr/bin/scriptindex'

# omindex binary path
# To index "non-text" files, use omindex filters
# e.g.: tesseract OCR engine as a filter for PNG files
# OMINDEX = "/usr/bin/omindex --filter=image/png:'tesseract %f -'"
OMINDEX = '/usr/bin/omindex'

# Directory containing Xapian databases for omindex (Attachments indexing)
DBROOTPATH = File.expand_path('file_index', REDMINE_ROOT)

# Verbose output, false/true
verbose = false

# Define stemmed languages to index attachments Eg. [ 'english', 'italian', 'spanish' ]
# Repository database will always be indexed in english
# Available languages are danish dutch english finnish french german german2 hungarian italian kraaij_pohlmann lovins
# norwegian porter portuguese romanian russian spanish swedish turkish:
stem_langs	= ['english']

# Project identifiers whose repositories will be indexed eg. [ 'prj_id1', 'prj_id2' ]
# Use [] to index all projects
projects	= []

# Temporary directory for indexing, it can be tmpfs
tempdir	= '/tmp'

# Binaries for text conversion
PDFTOTEXT = '/usr/bin/pdftotext -enc UTF-8'
CATDOC = '/usr/bin/catdoc'
XLSTOCSV = '/usr/bin/xls2csv'
CATPPT = '/usr/bin/catppt'
UNZIP = '/usr/bin/unzip -o'
UNRTF = '/usr/bin/unrtf -t text 2>/dev/null'

########################################################################################################################
# END Configuration parameters
########################################################################################################################

ENVIRONMENT = File.join(REDMINE_ROOT, 'config/environment.rb')

only_files = false
only_repos = false
env = 'production'
reset_log = false
retry_failed = false
reset_database = false
max_size = ''

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
  'pdf' => PDFTOTEXT,
  'doc' => CATDOC,
  'xls' => XLSTOCSV,
  'ppt' => CATPPT,
  'pps' => CATPPT,
  'docx' => UNZIP,
  'xlsx' => UNZIP,
  'pptx' => UNZIP,
  'ppsx' => UNZIP,
  'ods' => UNZIP,
  'odt' => UNZIP,
  'odp' => UNZIP,
  'rtf' => UNRTF
}.freeze

VERSION = '0.3'

optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: xapian_indexer.rb [OPTIONS...]'
  opts.separator('')
  opts.separator('Index redmine files and repositories')
  opts.separator('')
  opts.separator('')
  opts.separator('Options:')
  opts.on('-p', '--projects a,b,c', Array,
          'Comma separated list of identifiers of projects whose repositories will be indexed') { |p| projects = p }
  opts.on('-s', '--stemming_lang a,b,c', Array,
          'Comma separated list of stemming languages for indexing') { |s| stem_langs = s }
  opts.on('-v', '--verbose', 'verbose') { verbose = true }
  opts.on('-f', '--files', 'Only index Redmine attachments') { only_files = true }
  opts.on('-r', '--repositories', 'Only index Redmine repositories') { only_repos = true }
  opts.on('-e', '--environment ENV',
          'Rails ENVIRONMENT (development, testing or production), default production') { |e| env = e }
  opts.on('-t', '--temp-dir PATH', 'Temporary directory for indexing') { |t| tempdir = t }
  opts.on('-x', '--reset_log', 'Reset index log') { reset_log = true }
  opts.on('-X', '--reset-database', 'Reset database') { reset_database = true }
  opts.on('-V', '--version', 'show version and exit') do
    puts VERSION
    exit
  end
  opts.on('-h', '--help', 'show help and exit') do
    puts opts
    exit
  end
  opts.on('-R', '--retry-failed', 'retry files which omindex failed to extract text') { retry_failed = true }
  opts.on('-m', '--max-size SIZE', "maximum size of file to index(e.g.: '5M', '1G',...)") do |m|
    max_size = m
  end
  opts.separator('')
  opts.separator('Examples:')
  opts.separator(' xapian_indexer.rb -f -s english,italian -v')
  opts.separator(' xapian_indexer.rb -p project_identifier -x -t /tmpfs -v')
  opts.separator('')
  opts.summary_width = 25
end

optparse.parse!

ENV['RAILS_ENV'] = env

STATUS_SUCCESS = 1
STATUS_FAIL = -1
ADD_OR_UPDATE = 1
DELETE = 0

class IndexingError < StandardError; end

def repo_name(repository)
  repository.identifier.presence || 'main'
end

def indexing(databasepath, project, repository, tempdir, verbose)
  my_log "Fetch changesets: #{project.name} - #{repo_name(repository)}", verbose
  repository.fetch_changesets
  repository.reload.changesets.reload
  latest_changeset = repository.changesets.first
  revision = latest_changeset&.revision
  my_log("Latest revision: #{project.name} - #{repo_name(repository)} - #{revision}", verbose) if revision
  latest_indexed = Indexinglog.where(repository_id: repository.id, status: STATUS_SUCCESS).last
  my_log "Latest indexed: #{latest_indexed.inspect}", verbose
  begin
    indexconf = Tempfile.new('index.conf', tempdir)
    indexconf.write "url : field boolean=Q unique=Q\n"
    indexconf.write "body : index truncate=400 field=sample\n"
    indexconf.write "date: field=date\n"
    indexconf.close
    if latest_changeset && latest_indexed
      my_log "Repository #{repo_name(repository)} indexed, indexing diff", verbose
      indexing_diff_by_changesets databasepath, indexconf, project, repository, latest_indexed.changeset,
                                  latest_changeset, tempdir, verbose
    elsif latest_indexed
      my_log "Repository #{repo_name(repository)} indexed, indexing diff by time", verbose
      indexing_diff_by_time databasepath, indexconf, project, repository, latest_indexed.updated_at, tempdir, verbose
    else
      my_log "Repository #{repo_name(repository)} not indexed, indexing all", verbose
      indexing_diff_by_time databasepath, indexconf, project, repository, nil, tempdir, verbose
    end
    indexconf.unlink
  rescue IndexingError => e
    add_log repository, latest_changeset, STATUS_FAIL, verbose, e.message
  else
    add_log repository, latest_changeset, STATUS_SUCCESS, verbose
    my_log "Successfully indexed: #{[project.name, repo_name(repository), revision].compact_blank.join(' - ')}",
           verbose
  end
end

def supported_mime_type(entry)
  mtype = Redmine::MimeType.of(entry)
  MIME_TYPES.include?(mtype) || Redmine::MimeType.is_type?('text', entry)
end

def add_log(repository, changeset, status, verbose, message = nil)
  log = Indexinglog.where(repository_id: repository.id).last
  if log
    log.changeset_id = changeset ? changeset.id : -1
    log.status = status
    log.message = message
    log.save!
    my_log "Log for repo #{repo_name(repository)} updated!", verbose
  else
    log = Indexinglog.new
    log.repository = repository
    log.changeset = changeset
    log.status = status
    log.message = message
    log.save!
    my_log "New log for repo #{repo_name(repository)} saved!", verbose
  end
end

def delete_log(repository, verbose)
  Indexinglog.where(repository_id: repository.id).delete_all
  my_log "Log for repo #{repo_name(repository)} removed!", verbose
end

def delete_log_by_repo_id(repo_id, verbose)
  Indexinglog.where(repository_id: repo_id).delete_all
  my_log "Log for zombied repo #{repo_id} removed!", verbose
end

def walk(databasepath, indexconf, project, repository, identifier, entries, time_last_indexed, tempdir, verbose)
  return if entries.blank?

  my_log "Walk entries size: #{entries.size}", verbose
  entries.each do |entry|
    my_log "Walking into: #{entry.lastrev&.time}", verbose
    if entry.is_dir?
      walk databasepath, indexconf, project, repository, identifier, repository.entries(entry.path, identifier),
           time_last_indexed, tempdir, verbose
    elsif entry.is_file? && !entry.lastrev.nil? && (time_last_indexed.nil? || entry.lastrev.time > time_last_indexed) &&
          supported_mime_type(entry.path)
      add_or_update_index databasepath, indexconf, project, repository, identifier, entry.path, entry.lastrev,
                          ADD_OR_UPDATE, MIME_TYPES[Redmine::MimeType.of(entry.path)], tempdir, verbose
    end
  end
end

def indexing_diff_by_time(databasepath, indexconf, project, repository, time_last_indexed, tempdir, verbose)
  my_log "Indexing all: #{repo_name(repository)}", verbose
  begin
    if repository&.branches
      repository.branches.each do |branch|
        my_log "Walking in branch: #{repo_name(repository)} - #{branch}", verbose
        walk databasepath, indexconf, project, repository, branch, repository.entries(nil, branch), time_last_indexed,
             tempdir, verbose
      end
    else
      my_log "Walking in branch: #{repo_name(repository)} - [NOBRANCH]", verbose
      walk databasepath, indexconf, project, repository, nil, repository.entries(nil, nil), time_last_indexed,
           tempdir, verbose
    end
    repository&.tags&.each do |tag|
      my_log "Walking in tag: #{repo_name(repository)} - #{tag}", verbose
      walk databasepath, indexconf, project, repository, tag, repository.entries(nil, tag), time_last_indexed,
           tempdir, verbose
    end
  rescue StandardError => e
    my_log "#{repo_name(repository)} encountered an error and will be skipped: #{e.message}", true
    raise IndexingError, e.message
  end
end

def walkin(databasepath, indexconf, project, repository, identifier, changesets, tempdir, verbose)
  my_log "Walking into #{changesets.inspect}", verbose
  return unless changesets || changesets.size <= 0

  changesets.sort_by!(&:id)
  actions = {}
  # SCM actions
  #   * A - Add
  #   * M - Modified
  #   * R - Replaced
  #   * D - Deleted
  changesets.each do |changeset|
    my_log "Changeset changes for #{changeset.id} #{changeset.filechanges.inspect}", verbose
    next unless changeset.filechanges

    changeset.filechanges.each do |change|
      actions[change.path] = change.action == 'D' ? DELETE : ADD_OR_UPDATE
    end
  end
  return unless actions

  actions.each do |path, action|
    entry = repository.entry(path, identifier)
    next unless entry&.is_file? || (action == DELETE)

    if entry.nil? && (action != DELETE)
      my_log "Error indexing path: #{path.inspect}, action: #{action.inspect}, identifier: #{identifier.inspect}",
             true
    end
    my_log "Entry to index #{entry.inspect}", verbose
    lastrev = entry.lastrev if entry
    if supported_mime_type(path) || (action == DELETE)
      add_or_update_index databasepath, indexconf, project, repository, identifier, path, lastrev, action,
                          MIME_TYPES[Redmine::MimeType.of(path)], tempdir, verbose
    end
  end
end

def indexing_diff_by_changesets(databasepath, indexconf, project, repository, diff_from, diff_to, tempdir, verbose)
  if diff_from.id >= diff_to.id
    my_log "Already indexed: #{repo_name(repository)} (from: #{diff_from.id} to #{diff_to.id})", verbose
    return
  end
  my_log "Indexing diff: #{repo_name(repository)} (from: #{diff_from.id} to #{diff_to.id})", verbose
  my_log "Indexing all: #{repo_name(repository)}", verbose
  if repository&.branches
    repository.branches.each do |branch|
      my_log "Walking in branch: #{repo_name(repository)} - #{branch}", verbose
      walkin databasepath, indexconf, project, repository, branch,
             repository.latest_changesets('', branch, diff_to.id - diff_from.id)
                       .select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id }, tempdir,
             verbose
    end
  else
    my_log "Walking in branch: #{repo_name(repository)} - [NOBRANCH]", verbose
    walkin databasepath, indexconf, project, repository, nil,
           repository.latest_changesets('', nil, diff_to.id - diff_from.id)
                     .select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id }, tempdir,
           verbose
  end
  return unless repository&.tags

  repository.tags.each do |tag|
    my_log "Walking in tag: #{repo_name(repository)} - #{tag}", verbose
    walkin databasepath, indexconf, project, repository, tag,
           repository.latest_changesets('', tag, diff_to.id - diff_from.id)
                     .select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id }, tempdir,
           verbose
  end
end

def generate_uri(project, repository, identifier, path)
  Rails.application.routes.url_helpers.url_for controller: 'repositories',
                                               action: 'entry',
                                               id: project.identifier,
                                               repository_id: repository.identifier.presence || repository.id,
                                               rev: identifier,
                                               path: repository.relative_path(path),
                                               only_path: true
end

def convert_to_text(fpath, type, tempdir)
  text = +''
  return text unless File.exist?(FORMAT_HANDLERS[type].split.first)

  case type
  when 'pdf'
    text = `#{FORMAT_HANDLERS[type]} #{fpath} -`
  when /(xlsx|docx|odt|pptx)/i
    system "#{UNZIP} -d #{tempdir}/temp \"#{fpath}\" > /dev/null", out: '/dev/null'
    case type
    when 'xlsx'
      fouts = ["#{tempdir}/temp/xl/sharedStrings.xml"]
    when 'docx'
      fouts = ["#{tempdir}/temp/word/document.xml"]
    when 'odt'
      fouts = ["#{tempdir}/temp/content.xml"]
    when 'pptx'
      fouts = Dir["#{tempdir}/temp/ppt/slides/*.xml"]
    end
    begin
      fouts.each do |fout|
        text += "#{File.read(fout)}\n"
      end
      FileUtils.rm_rf "#{tempdir}/temp"
    rescue StabndardError => e
      my_log "Error: #{e.message} reading #{fouts.inspect}", true
    end
  else
    text = `#{FORMAT_HANDLERS[type]} #{fpath}`
  end
  text
end

def add_or_update_index(databasepath, indexconf, project, repository, identifier, path, lastrev, action, type, tempdir,
                        verbose)
  uri = generate_uri(project, repository, identifier, path)
  return unless uri

  text = nil
  if Redmine::MimeType.is_type?('text', path) || %(js).include?(type)
    text = repository.cat(path, identifier)
  else
    fname = path.split('/').last.tr(' ', '_')
    bstr = repository.cat(path, identifier)
    File.open("#{tempdir}/#{fname}", 'wb+') do |bs|
      bs.write bstr
    end
    text = convert_to_text("#{tempdir}/#{fname}", type, tempdir) if File.exist?("#{tempdir}/#{fname}") && !bstr.nil?
    File.unlink "#{tempdir}/#{fname}"
  end
  my_log "generated uri: #{uri}", verbose
  my_log('Mime type text', verbose) if Redmine::MimeType.is_type?('text', path)
  my_log "Indexing: #{path}", verbose
  begin
    itext = Tempfile.new('filetoindex.tmp', tempdir)
    itext.write "url=#{uri}\n"
    if action == DELETE
      my_log "Path: #{path} should be deleted", verbose
    else
      sdate = lastrev.time || Time.at(0).in_time_zone
      itext.write "date=#{sdate}\n"
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
    end
    itext.close
    my_log "TEXT #{itext.path} generated", verbose
    my_log "Index command: #{SCRIPTINDEX} -s english #{databasepath} #{indexconf.path} #{itext.path}",
           verbose
    system_or_raise "#{SCRIPTINDEX} -s english #{databasepath} #{indexconf.path} #{itext.path}", verbose
    itext.unlink
    my_log 'New doc added to xapian database', verbose
  rescue StandardError => e
    my_log e.message, true
  end
end

def my_log(text, verbose, error: false)
  if error
    warn text
  elsif verbose
    $stdout.puts text
  end
end

def system_or_raise(command, verbose)
  if verbose
    system command, exception: true
  else
    system command, out: '/dev/null', exception: true
  end
end

def find_project(prt)
  project = Project.active.has_module(:repository).find_by(identifier: prt)
  if project
    my_log "Project found: #{project}", verbose
  else
    my_log "Project #{prt} not found", verbose, error: true
  end
  @project = project
end

my_log "Trying to load Redmine environment <<#{ENVIRONMENT}>>...", verbose

begin
  require ENVIRONMENT
  my_log "Redmine environment [RAILS_ENV=#{env}] correctly loaded ...", verbose

  # Indexing files
  unless only_repos
    stem_langs.each do |lang|
      filespath = Redmine::Configuration['attachments_storage_path'] || File.join(REDMINE_ROOT, FILES)
      unless File.directory?(filespath)
        my_log "An error while accessing #{filespath}, exiting...", true
        exit 1
      end
      databasepath = File.join(DBROOTPATH, lang)
      FileUtils.rm_rf(databasepath) if File.directory?(databasepath) && reset_database
      unless File.directory?(databasepath)
        my_log "#{databasepath} does not exist, creating ...", verbose
        FileUtils.mkdir_p databasepath
      end
      cmd = "#{OMINDEX} -s #{lang} --db #{databasepath} #{filespath}  --url / --depth-limit=0"
      cmd << ' -v' if verbose
      cmd << ' --retry-failed' if retry_failed
      cmd << " -m #{max_size}" if max_size.present?
      my_log cmd, verbose
      system_or_raise cmd, verbose
    end
    my_log 'Redmine files indexed', verbose
  end

  # Indexing repositories
  unless only_files
    unless File.exist?(SCRIPTINDEX)
      my_log "#{SCRIPTINDEX} does not exist, exiting...", true
      exit 1
    end
    databasepath = File.join(DBROOTPATH, 'repodb')
    FileUtils.rm_rf(databasepath) if File.directory?(databasepath) && reset_database
    unless File.directory?(databasepath)
      my_log "Db directory #{databasepath} does not exist, creating...", verbose
      FileUtils.mkdir_p databasepath
    end
    projects = Project.active.has_module(:repository).pluck(:identifier) if projects.blank?
    projects.each do |identifier|
      project = Project.active.has_module(:repository).where(identifier: identifier).preload(:repository).first
      if project
        my_log "- Indexing repositories for #{project}...", verbose
        repositories = project.repositories.select(&:supports_cat?)
        repositories.each do |repository|
          delete_log(repository, verbose) if reset_log
          indexing databasepath, project, repository, tempdir, verbose
        end
      else
        my_log "Project identifier #{identifier} not found or repository module not enabled, ignoring...", verbose
      end
    end
    if reset_log
      existing_repo_ids = Repository.all.to_a.map(&:id)
      zombied_repo_ids = Indexinglog.where.not(repository_id: existing_repo_ids).to_a.map(&:repository_id).uniq
      zombied_repo_ids.each do |zombied_repo_id|
        delete_log_by_repo_id zombied_repo_id, verbose
      end
    end
  end
rescue LoadError => e
  my_log e.message, true
  exit 1
end

exit 0
