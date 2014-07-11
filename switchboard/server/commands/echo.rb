module Commands
  # Echo back what ever is sent
  def echo
    while incoming = read_line
      write_line incoming
    end
  end
end
