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


require 'action_view'
include ERB::Util
include ActionView::Helpers::TagHelper 

module SearchHelper2

  def self.highlight_tokens2(text, tokens)
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
        result << h(words)
      else
        t = (tokens.index(words.downcase) || 0) % 6
        result << content_tag('span', h(words), :class => "highlight token-#{t}")
      end
    end
    result.html_safe
  end

end
