Redmine Xapian search plugin
============================

The current version of Redmine Xapian is **1.6.8**
With this plugin you will be able to make searches by file name and by strings inside your attachments through the [Xapian 
search engine](https://xapian.org). This plugin can also index the files located in your repositories. This plugin 
replaces search controller, its view and search methods.

## 1.  Installation and Setup

A copy of the plugin can be downloaded from  Github at https://github.com/xelkano/redmine_xapian/downloads.

### 1.1. Required packages

Redmine >= 3.0

To use the full-text search engine you must install ruby-xapian and xapian-omega packages. In case of using of Bitnami 
stack or Ruby installed via RVM it might be necessary to install Xapian bindings from sources.  See https://xapian.org
 for details. To index some files with omindex you may have to install some other packages like xpdf, antiword, ...
 
```
sudo apt-get install xapian-omega ruby-xapian
```

To index some files with omega you may have to install some other packages like
xpdf, antiword, ...

From "Omega documentation":http://xapian.org/docs/omega/overview.html:

   * HTML (.html, .htm, .shtml, .shtm, .xhtml, .xhtm)
   * PHP (.php) - our HTML parser knows to ignore PHP code
   * text files (.txt, .text)
   * SVG (.svg)
   * CSV (Comma-Separated Values) files (.csv)
   * PDF (.pdf) if pdftotext is available (comes with poppler or xpdf)
   * PostScript (.ps, .eps, .ai) if ps2pdf (from ghostscript) and pdftotext (comes with poppler or xpdf) are available
   * OpenOffice/StarOffice documents (.sxc, .stc, .sxd, .std, .sxi, .sti, .sxm, .sxw, .sxg, .stw) if unzip is available
   * OpenDocument format documents (.odt, .ods, .odp, .odg, .odc, .odf, .odb, .odi, .odm, .ott, .ots, .otp, .otg, .otc, .otf, .oti, .oth) if unzip is available
   * MS Word documents (.dot) if antiword is available (.doc files are left to libmagic, as they may actually be RTF (AbiWord saves RTF when asked to save as .doc, and Microsoft Word quietly loads RTF files with a .doc extension), or plain-text).
   * MS Excel documents (.xls, .xlb, .xlt, .xlr, .xla) if xls2csv is available (comes with catdoc)
   * MS Powerpoint documents (.ppt, .pps) if catppt is available (comes with catdoc)
   * MS Office 2007 documents (.docx, .docm, .dotx, .dotm, .xlsx, .xlsm, .xltx, .xltm, .pptx, .pptm, .potx, .potm, .ppsx, .ppsm) if unzip is available
   * Wordperfect documents (.wpd) if wpd2text is available (comes with libwpd)
   * MS Works documents (.wps, .wpt) if wps2text is available (comes with libwps)
   * MS Outlook message (.msg) if perl with Email::Outlook::Message and HTML::Parser modules is available
   * MS Publisher documents (.pub) if pub2xhtml is available (comes with libmspub)
   * AbiWord documents (.abw)
   * Compressed AbiWord documents (.zabw)
   * Rich Text Format documents (.rtf) if unrtf is available
   * Perl POD documentation (.pl, .pm, .pod) if pod2text is available
   * reStructured text (.rst, .rest) if rst2html is available (comes with docutils)
   * Markdown (.md, .markdown) if markdown is available
   * TeX DVI files (.dvi) if catdvi is available
   * DjVu files (.djv, .djvu) if djvutxt is available
   * XPS files (.xps) if unzip is available
   * Debian packages (.deb, .udeb) if dpkg-deb is available
   * RPM packages (.rpm) if rpm is available
   * Atom feeds (.atom)
   * MAFF (.maff) if unzip is available
   * MHTML (.mhtml, .mht) if perl with MIME::Tools is available
   * MIME email messages (.eml) and USENET articles if perl with MIME::Tools and HTML::Parser is available
   * vCard files (.vcf, .vcard) if perl with Text::vCard is available

On Debian you can use following command to install some of the required indexing tools:

```
sudo apt-get install xapian-omega libxapian-dev xpdf poppler-utils \
    antiword unzip catdoc libwpd-tools libwps-tools gzip unrtf catdvi \
    djview djview3 uuid uuid-dev xz-utils libemail-outlook-message-perl
```

### 1.2. Plugin installation

Install redmine_xapian into the plugins directory with:

```
cd redmine/plugins
git clone https://github.com/xelkano/redmine_xapian.git
cd ..
bundle install
bundle exec rake redmine:plugins:migrate RAILS_ENV="production"
```

And after that restart the application server.

Now, you can see new check boxes _Files_ and _Repositories_ on the search screen, those allows you to search attachments 
by file name and its contents. Xapian plugin checks for ruby bindings before its startup. If the plugin can not find them,
it is not activated and the following message is going to appear in Redmine log “No Xapian search engine interface for 
Ruby installed" If you see this message, please make sure that a Xapian search engine interface is installed.

### 1.3. Setup

First at all, go to the Redmine interface and in the plugins section configure the plugin. It's very important to set up 
correctly the directory that will contain the Xapian databases.

To use stemmed languages in searches, Xapian needs to generate stemmed forms for each language and store them in a database.
Before you can use the plugin, you have to populate the Xapian databases for each stemmed language you want to use. 
From plugin version 1.6 a new script (xapian_indexer.rb) is included in the extra directory that is use to populate Xapian
databases. This script is a wrapper for omindex binary, so omindex should not to be used anymore.

First edit the script file and configure the required variables, they are self-explanatory and most of them can be 
specified and overwritten through the command line.

To view command line help simply run `xapian_index.rb -h`. To view the complete process you can run it using verbose 
flag (-v).

Note, that the first time you index a repository it can take a long time. After the first indexation the process is much 
faster.
You have to take into account that the script needs a defined repository identifier for all repositories that will be 
indexed. The repository identifier is not required in redmine and can have null value for some of the repositories, so 
before indexing a repository you have to be sure that the repository has a defined identifier, otherwise the script 
will ignore it.

There is a rake task for setting up a default identifier for your repositories:

```
bundle exec rake redmine:xapian_set_identifiers identifier='main' RAILS_ENV="production"
```

Examples running the script:

Run the script based in its configuration in verbose mode, index repositories and files:

```
ruby xapian_indexer.rb -v
```

Only index redmine files:

```
ruby xapian_indexer.rb -v -f
```

Only index repositories:

```
xapian_indexer.rb -v -r
```

Indexing repositories of some projects (valid for repositories indexing only):

```
xapian_indexer.rb -v -r -p project_identifier1,project_identifier2
```

**Configure a cron task for an automatic indexing**

Once you have tested the script functionality, you can configure it for running every day at nights keeping your Xapian
database up to date, for example:

```
@daily www-data ruby /usr/bin/xapian_indexer.rb
```

After files indexing and the plugin setup in the settings you can search attachments by name and content.

To perform searches in a particular module such as Files, Documents,... it is
mandatory to enable these modules in your projects and to have corresponding
permissions view_*; Be sure it is checked.

### Hooks

There are a few hooks to customize the Xapian search plugin behaviour in your onw plugin:

#### Quick jump to an object

```
:controller_search_quick_jump
```

An example of a direct jump to a document by entering D{ID} in DMSF plugin

```
    class ControllerSearchHook < RedmineDmsf::Hooks::Listener
                        
      def controller_search_quick_jump(context={})
        if context.is_a?(Hash) 
          question = context[:question]
          if question.present?
            if question.match(/^D(\d+)$/) && DmsfFile.visible.find_by_id($1.to_i)
              return { :controller => 'dmsf_files', :action => 'show', :id => $1.to_i }
            end
          end
        end        
      end      
                  
    end
```

#### Parent container in searched results

```
:view_search_index_container
```

An example of displaying the parent folder of the searched document in DMSF plugin

``` 
    class ViewSearchFormHook < Redmine::Hook::ViewListener

      def view_search_index_container(context={})
        if context && context[:object].is_a?(DmsfFile)
          dmsf_file = context[:object]
          title = ''
          if dmsf_file.dmsf_folder_id
            dmsf_folder = DmsfFolder.find_by_id dmsf_file.dmsf_folder_id
            title = dmsf_folder.title if dmsf_folder
          else
            title = dmsf_file.project.name
          end
          link_to(h(title),
      dmsf_folder_path(:id => dmsf_file.project, :folder_id => dmsf_file.dmsf_folder_id),
            :class => 'icon icon-folder') + ' / '
        end
      end

    end
```