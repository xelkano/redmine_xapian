# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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



module XapianHelper

  def highlight_tokens2(text, tokens)
    Rails.logger.debug "DEBUG: highlight_tokens2 "
    return text unless text && tokens && !tokens.empty?
    re_tokens = tokens.collect {|t| Regexp.escape(t)}
    regexp = Regexp.new "(#{re_tokens.join('|')})", Regexp::IGNORECASE
    result = ''
    text.split(regexp).each_with_index do |words, i|
      if result.length > 3000
        # maximum length of the preview reached
	Rails.logger.debug "DEBUG: maximum length reached"
        result << '...'
        break
      end
      words = words.mb_chars
      if i.even?
        result << words
      else
        t = (tokens.index(words.downcase) || 0) % 6
        result << content_tag('span', words, :class => "highlight token-#{t}")
      end
    end
    result.html_safe
  end

   def page_entries_info2(collection)
     unless collection.nil?
       case collection.size
       when 0
         l(:label_no_results_found)
       when 1
         l(:label_one_result_found)
       else
         l(:label_show_all_results, :total_entries=>"#{collection.total_entries}", :offsetfirst=>"#{collection.offset + 1}", :offsetlast=>"#{collection.offset + collection.length}" )
       end
     end
   end


end
