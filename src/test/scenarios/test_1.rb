require 'msgpack'
require 'digest'

class Requester

  def request(msgid, method, params)
    msg  = [0, msgid, method, params].to_msgpack.each_byte.map{|ch| sprintf("0x%02X",ch)}.join(',')
    snr  = "- I  :\n" << "  - XFER   : {DATA: [#{msg}]}\n"
  end

end

class Responder

  def response(msgid, error, result)
    msg = [1, msgid, error, result].to_msgpack.each_byte.map{|ch| sprintf("0x%02X",ch)}.join(',')
    snr = "- O  :\n" << "  - XFER   : {DATA: [#{msg}], LAST:1}\n"
  end

end

class AXI4Slave

  def read(addr, data)
    h_addr = sprintf("0x%08X", addr)
    h_data = "[" + data.map{|ch| sprintf("0x%02X", ch)}.join(",") + "]"
    snr    = "- M  :\n" << "  - READ   : {ADDR: #{h_addr}, DATA: #{h_data}}\n"
  end
end

def padding(data)

  def bit_length_vector(bit_length)
    vector = []
    vector.push((bit_length & 0xFF00000000000000) >> 54)
    vector.push((bit_length & 0x00FF000000000000) >> 48)
    vector.push((bit_length & 0x0000FF0000000000) >> 40)
    vector.push((bit_length & 0x000000FF00000000) >> 32)
    vector.push((bit_length & 0x00000000FF000000) >> 24)
    vector.push((bit_length & 0x0000000000FF0000) >> 16)
    vector.push((bit_length & 0x000000000000FF00) >>  8)
    vector.push((bit_length & 0x00000000000000FF) >>  0)
    return vector
  end

  new_data = data.dup
  new_data.push(0x80)
  padding_size = 64 - (new_data.length % 64) - 8
  if padding_size < 0 then
    padding_size = padding_size + 64
  end
  new_data.concat Array.new(padding_size, 0x00)
  new_data.concat bit_length_vector(data.length * 8)
  return new_data
end

def reverse_bit_per_byte(data)
  return data.map{|ch| ((ch & 0x01) << 7) | ((ch & 0x02) << 5) | ((ch & 0x04) << 3) | ((ch & 0x08) << 1) |
                       ((ch & 0x10) >> 1) | ((ch & 0x20) >> 3) | ((ch & 0x40) >> 5) | ((ch & 0x80) >> 7)}
end

def conv_be32(data)
  new_data = []
  while data.length > 0 do
    word_vec = data.shift(4)
    new_data.concat word_vec.reverse
  end
  return new_data
end

def test_1(file, i, o, m, addr, data, digest)
  msg_id   = 0x22
  addr_str = sprintf("0x%08X", addr);
  src_data = padding(data)
  blocks   = src_data.length/64

  file.puts "- MARCHAL  : "
  file.puts "  - SAY    : sha256(#{addr_str}, #{blocks})"
  file.puts "---"

  file.puts i.request( msg_id, "sha256", [addr, blocks])

  blocks.times do
    block_data = src_data.shift(64)
    file.puts m.read(addr, block_data)
    addr = addr + 64
  end

  file.puts o.response(msg_id, nil, digest)
end

File.open('test_1.snr','w') do |file|

  i = Requester.new
  o = Responder.new
  m = AXI4Slave.new

  file.puts "---"
  file.puts "- MARCHAL  : "
  file.puts "  - SAY    : SHA256_Server TEST 1 Start."
  file.puts "---"
  file.puts "- MARCHAL  : "
  file.puts "  - SAY    : SHA256_Server TEST 1.1 Start."
  file.puts "---"

  # data   =  "abc".unpack("C*")
  data   =  "".unpack("C*")
  digest = Digest::SHA256.digest(data.pack("C*"))
  test_1(file, i, o, m, 0x12000000, data, digest)

  file.puts "- MARCHAL  : "
  file.puts "- SAY      : SHA256_Server TEST 1 Done."
  file.puts "---"
end
