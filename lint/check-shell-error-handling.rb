
#!/usr/bin/env ruby

def check_file file_name
  file_name_displayed = false
  skip_heredoc = false
  case_statement = false

  lines = File.readlines(file_name)
  lines.each_with_index do |line, index|

    # heredoc
    if skip_heredoc
      if line =~ Regexp.new("\\A#{skip_heredoc}\\z")
        skip_heredoc = false
      end
      next
    end

    if match = line.match(/\<\<-??'??(\w+)/)
      skip_heredoc = match[1]
    end


    # case statement
    if line =~ /\A\s*case\s+.*\s*in\s*\z/
      case_statement = true
      next
    end

    if case_statement
      next if line =~ /\A\s*\;\;\s*\z/
      next if line =~ /\)\s*\z/
    end

    if line =~ /\A\s*esac\s*\z/
      case_statement = false
      next
    end


    # empty line
    next if line =~ /\A\s*\z/

    # error handling with fail
    next if line =~ /\|\|\s+fail[\s\z]/

    # error handling with ||
    next if line =~ /\|\|\s+\{.*\}\s*\z/

    # error handling with "|| true"
    next if line =~ /\|\|\s+true\s*\z/

    # \ at the end of the line
    next if line =~ /\\\s*\z/

    # set command
    next if line =~ /\A\s*set /

    # return command
    next if line =~ /\A\s*return /

    # exit command
    next if line =~ /\A\s*exit /

    # fail command
    next if line =~ /\A\s*fail /

    # export command
    next if line =~ /\A\s*export / && ! (line =~ /\$\(/)

    # local command
    next if line =~ /\A\s*local / && ! (line =~ /\$\(/)

    # assign variable
    next if line =~ /\A\s*[\w\_]+\s*=/ && ! (line =~ /\$\(/)

    # echo command
    next if line =~ /\A\s*echo / && ! (line =~ /\$\([^\(]/) && ! (line =~ /\|/)

    # opening bracket for function
    next if line =~ /\A[\w\_\-\:]+\s*\(\)\s*[{(]\s*\z/

    # closing bracket for function
    next if line =~ /\A\s*[})]\s*\z/

    # comment
    next if line =~ /\A\s*#.*/

    # if ... then
    next if line =~ /\A\s*if\s+.*;\s+then\s*\z/

    # elif ... then
    next if line =~ /\A\s*elif\s+.*;\s+then\s*\z/

    # else
    next if line =~ /\A\s*else\s*\z/

    # fi
    next if line =~ /\A\s*fi\s*\z/

    # done
    next if line =~ /\A\s*done\s*\z/

    # true
    next if line =~ /\A\s*true\s*\z/

    # false
    next if line =~ /\A\s*false\s*\z/

    # array add
    next if line =~ /\A\s*\w+\+\=\(.*\)\s*\z/

    # opening bracket
    next if line =~ /\A\s*\(\s*\z/

    # PIPESTATUS check
    next if line =~ /\s+\|\s+/ && lines[index+1] =~ /PIPESTATUS/

    unless file_name_displayed
      file_name_displayed = true
      puts "\n#{file_name}:"
    end

    puts "  #{index+1}: #{line}"
  end
end

ARGV.each do |file_name|
  check_file file_name
end
