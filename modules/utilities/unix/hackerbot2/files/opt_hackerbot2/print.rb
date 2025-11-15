
class Print
  def self.colorize(text, color_code)
    "#{color_code}#{text}\e[0m"
  end

  def self.red(text); colorize(text, "\e[31m"); end
  def self.green(text); colorize(text, "\e[32m"); end
  def self.yellow(text); colorize(text, "\e[33m"); end
  def self.blue(text); colorize(text, "\e[34m"); end
  def self.purple(text); colorize(text, "\e[35m"); end
  def self.cyan(text); colorize(text, "\e[36m"); end
  def self.grey(text); colorize(text, "\e[37m"); end
  def self.bold(text); colorize(text, "\e[2m"); end

  def self.debug(msg)
    puts purple(' ' + msg.to_s)
  end

  def self.verbose(msg)
    puts grey(' ' + msg.to_s)
  end

  def self.err(msg)
    $stderr.puts red(msg.to_s)
  end

  def self.info(msg)
    puts green(msg.to_s)
  end

  def self.warn(msg)
    puts yellow(msg.to_s)
  end

  def self.std(msg)
    puts yellow(msg.to_s)
  end

  # local encoders/generators write messages to stderr (stdout used to return values)
  def self.local(msg)
    $stderr.puts cyan(msg.to_s)
  end
  def self.local_verbose(msg)
    $stderr.puts cyan(' ' + msg.to_s)
  end

end
