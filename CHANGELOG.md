Changelog for Redmine Xapian
============================

3.0.6 *????-??-??*
------------------

3.0.5 *2023-11-15*
------------------

    Issue filter in the search view
    Redmine 5.1 compatibility 

3.0.4 *2023-07-14*
------------------

    Visibility of the option Search open issues only

* Bug: #143 - Redmine Xapian package removes search "opened issues only" option in Redmine.

3.0.3 *2023-06-05*
------------------
    Repository identifiers are no more required for indexing repositories. Reindex your database to have correct URLs for repositories without an identifier
    Fultext-search in images using OCR
    Rubocop tests of the plugin's source codes

* Bug: #141 - JSON::ParserError (859: unexpected token at...
* Bug: #140 - NameError: uninitialized constant RedmineXapian::XapianSearch::Xapian
* Bug: #139 - Undefined method `to_a' for #<Project id ...
* Bug: #138 - Repository regex
* Bug: #137 - Fix for xlsx name containing '('
* New: #136 - Attachments storage path
* New: #135 - OCR support Feature
* Bug: #131 - Conflict installing redmine_xapian 3.0.2 for Redmine 5.0.2 in Debian

3.0.2 *2022-11-01*
------------------
    Ruby 3.0

* Bug: #130 - NoMethodError (undefined method 'unescape' for URI:Module)

3.0.1 *2022-09-20*
------------------
    GitHub CI

3.0.0 *2022-04-28*
------------------
    Redmine 5.0

* Bug: #127 - Update README.md
* New: #126 - Rails 6
* New: #125 - Gitlab CI

2.0.5 *2021-10-08*
------------------
    Indexing if Redmine is run in a sub-uri
    An option to delete the index database
    Chinese characters in file names and in searched text fixed
    Indexing of file system repositories

* Bug: #124 - Fix url parsing
* New: #123 - indexing_diff_by_time: only index those updated or added after last i…
* Bug: #121 - pptx indexing: reading from docProps/app.xml -> ppt/slides/*.xml
* New: #120 - Add -X option for deleting database
* Bug: #119 - Fix for chinese-title-file
* Bug: #116 - Re-solve #88 pdf and Word(.doc) files are not seachable
* New: #115 - extra/xapian_indexer.rb -x: remove log for zombied repos
* Bug: #114 - "<repo_name> encountered an error and will be skipped: undefined method `split' for nil:NilClass
* New: ##113 - Make filesystem repository searchable
* Bug: #112 - Fix encoding condition
* Bug: #111 - In search result, chinese description is garbled

2.0.4 *2021-04-30*
------------------
    Maintenance release

* Bug: #109 - Bad repository link on search results

2.0.3 *2020-11-25*
------------------
    Maintenace release
    
* Bug: #106 - Can't open Xapian database on redmine 4.1.1

2.0.2 *2020-06-12*
------------------
    Maintenace release

2.0.1 *2020-01-21*
------------------
    Compatibility with Redmine 4.1.0

2.0.0 *2019-02-28*
------------------
    Compatibility with Redmine 4.0.0

* Bug: #95 - Exception thrown when I run ruby xapian_indexer.rb -v -f
* New: #94 - Please make it compatible with Redmine 4.0.0 

1.6.9 *2018-12-04*
------------------
    Support for searching Chinese/Japanese characters
        
* Bug: #91 - Xapian not indexing repository if project configuration is blank Bug
* Feature #90 - Question: How to make Japanese/Chinese characters searchable? Feature
* Feature #72 - Fulltext search options mix up redmine-modules and attachement-location to search Feature

1.6.8 *2018-04-06*
------------------
    Bugs fixing
    --retry-failed options in xapian_indexer.rb
    Rails 5 compliance
    
IMPORTANT

 `alias_method_chain` has been replaced with `prepend`. Consequently, there might occure conficts with plugins 
which overwrite the same methods.     

* Bug: #88 - pdf and Word(.doc) files are not seachable
* New: #86 - alias_method_chain is deprecated
* New: #85 - Add "--retry-failed" to omindex in xapian_indexer.rb
* Bug: #84 - Plugin redmine_xapian was not found.

1.6.7 *2017-09-12*
------------------
    A view hook for searched object container
    Xapian bindings dependency changed

IMPORTANT

The plugin is independent of the gem xapian-full-alaveteli which has been replaced with ruby-xapian package. Therefore
is recommended to uninstall xapian-full-alaveteli gem and install ruby-xapian package in order the full-text search
is working.

* New: #80 - eml files not being found
* New: #79 - A better navigation in found results
* Bug: #78 - Question. Can't open Xapian database

1.6.6 *2016-10-21*
------------------
    Maintenance release

* Bug: #76 - Index all repositories
* Bug: #74 - Search results for tickets truncated?

1.6.5 *2016-06-13*
------------------
    Search options saved in the user's preferences
    Quick jump to DMSF documents (Dxxx)
    Fixed an unhandled exception when repo doesn't exist on indexing
    Fixed an exception when walking into an entry without the last revision
    Allow walking all active project repositories
    Allow searching repositories that don't have an identifier
    Attempt to find revisions/ branches/ tags in docdash url and pull into repofile model
    Add enhanced styling for repo search results - branch/rev/tag bubbles
    Pass indexed url to the repofile model instead of rebuilding the url (issue with in-line url branch names)

* Bug: #68 - Search Repository not returning results in redmine 3.2
* New: #67 - Search options saved in the user's preferences.

1.6.4 *2015-12-18*
------------------
    Full search as default in options

1.6.3 *2015-09-11*
------------------
    Searching in repositories
    Unit tests

* Bug: #59 - search.rb

1.6.2 *2015-06-14*
------------------
    Redmine 3.x compatibility  

1.6.1
-----

* Bug: #44 - Not all results are shown 

1.6.0
-----
    Added support for repository indexing and search 
    (thanks to Kosei Kitahara for his work on Redmine reposearch plugin and Prevas company for supporting)

1.5.1
-----
    Support for Redmine 2.3

1.5.0
-----
    New permission model + bug fixes + code cleaning + new pagination

1.4.3
-----
    Compatibility for ruby1.9, tested on Redmine 2.0.3 + Ruby 1.9.2 + Rails 3.2.6

1.4.1
-----
    Set logger to info

1.4.0
-----
    Compatibility for Redmine 2, tested on Redmine 2.0.3 + Ruby 1.8.7 + Rails 3.2.6

1.3.0
-----
    Compatibility for Redmine 1.4, tested on 1.4.4

1.2.4
-----
    Minor bug fixes
    Remove attachment permission, it is no longer needed

1.2.3
-----
    Tested in Redmine 1.3.0

1.2.2
-----

* Bug: #14 - Searching in Files module 

1.2.1
-----

* Bug: #16 - Bad link on result page 

1.2.0
-----
    Support for searches in multiple stemmed languages 
    Tested in Redmine 1.2.1 and xapian packages 1.2.7.
    Bug fixes

1.1.6
-----
    Fix issue on searches with article container

1.1.5
-----
    Fix issue when knowledgebase plugin is not installed

1.1.4
-----

* Bug: #10 - Error disabling Xapian

1.1.3
-----
    Added support for article container to allow integration with knowledgebase plugin

1.1.2
-----
    German localization added

* Bug: #2 - Installation problem

1.1.1
-----
* Bug: #1 - Settings don't work 

1.1.0
-----
    Enhanced search results view screen

1.0.1
-----
    Attachments permission added because search_controller definitely needs it

1.0.0
-----
    First stable release