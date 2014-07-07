webRCX = do ->

  writeInt8 = (bytes, offset, value)->
    bytes[offset] = value & 0xff

  writeInt16 = (bytes, offset, value)->
    bytes[offset] = value & 0xff
    value >>>= 8
    bytes[offset + 1] = value & 0xff

  writeInt32 = (bytes, offset, value)->
    bytes[offset] = value & 0xff
    value >>>= 8
    bytes[offset + 1] = value & 0xff
    value >>>= 8
    bytes[offset + 2] = value & 0xff
    value >>>= 8
    bytes[offset + 3] = value & 0xff

  writeString = (bytes, offset, value)->
    for i in [0...value.length]
      bytes[offset + i] = value.charCodeAt(i)

  class Opcode
    constructor: (commands)->
      code = commands
        .map((_)-> [_ & 0xff, ~_ & 0xff])
        .reduce (rslts, [a, b], [])-> rslts.concat(a, b)
      sum = commands
        .reduce (rslt, _)-> (rslt + _) & 0xff
      @value = [
        0x55 # leader
        0xff # header
        0x00 # ~header
      ].concat code, [sum & 0xff, ~sum & 0xff]
    toPackets: ->
      new Packets(@value)

  do ->
    opcode = new Opcode([12, 255])
    console.assert opcode.value.every (v, i)->
      v is [85, 255, 0, 12, 243, 255, 0, 11, 244][i]


  class Packet
    constructor: (byte)->
      bits = (Number v for v in byte.toString(2))
      bits.unshift 0 while bits.length < 8
      sum = bits.reduce (a, b)-> a + b
      parity = if sum % 2 is 0 then 1 else 0
      @value = [
        1      # start bit
      ].concat bits, [
        parity # odd parity bit
        1      # stop bit
      ]

  do ->
    packet = new Packet(0x55)
    console.assert packet.value.every (v, i)->
      v is [1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1][i]


  class Packets
    constructor: (ary)-> 
      @value = ary.map (_)-> new Packet _
    toWavBytes: ->
      bits = @value
        .map((packet)-> packet.value)
        .reduce (rslt, ary, [])-> rslt.concat ary
      size = 32 * bits.length
      channel = 2
      sampleRate = 38200
      bitsPerSample = 8
      offset = 44
      bytes = new Uint8Array(offset + size)
      writeString(bytes, 0, "RIFF")  # Chunk ID (0x52494646)
      writeInt32(bytes, 4, offset + size - 8) # Chunk Size
      writeString(bytes, 8, "WAVE")  # Format (0x57415645)
      writeString(bytes,12, "fmt ")  # Subchunk 1 ID (0x666D7420)
      writeInt32(bytes,16, 16)          # Subchunk 1 Size
      writeInt16(bytes,20, 1)           # Audio Format
      writeInt16(bytes,22, channel)     # Num Channels
      writeInt32(bytes,24, sampleRate) # Sample Rate (Hz)
      writeInt32(bytes,28, sampleRate * channel * (bitsPerSample / 8)) # Byte Rate (サンプリング周波数 * ブロックサイズ)
      writeInt16(bytes,32, channel * (bitsPerSample / 8)) # Block Align (チャンネル数 * 1サンプルあたりのビット数 / 8)
      writeInt16(bytes,34, bitsPerSample) # Bits Per Sample
      writeString(bytes,36, "data")  # Subchunk 2 ID (0x64617461)
      writeInt32(bytes,40, size)        # Subchunk 2 Size
      j = 0
      for i in [offset...offset+size] by 32
        if bits[j++] is 0
          writeInt32(bytes,   i, 0xFF0000FF)
          writeInt32(bytes, 4+i, 0xFF0000FF)
          writeInt32(bytes, 8+i, 0xFF0000FF)
          writeInt32(bytes,12+i, 0xFF0000FF)
          writeInt32(bytes,16+i, 0xFF0000FF)
          writeInt32(bytes,20+i, 0xFF0000FF)
          writeInt32(bytes,24+i, 0xFF0000FF)
          writeInt32(bytes,28+i, 0xFF0000FF)
        else
          writeInt32(bytes,   i, 0x80808080)
          writeInt32(bytes, 4+i, 0x80808080)
          writeInt32(bytes, 8+i, 0x80808080)
          writeInt32(bytes,12+i, 0x80808080)
          writeInt32(bytes,16+i, 0x80808080)
          writeInt32(bytes,20+i, 0x80808080)
          writeInt32(bytes,24+i, 0x80808080)
          writeInt32(bytes,28+i, 0x80808080)
      bytes

  send: (args...)->
    opcode = new Opcode args
    packets = opcode.toPackets()
    bytes = packets.toWavBytes()
    blob = new Blob [bytes], {type: "audio/wav"}
    url = URL.createObjectURL(blob)
    console.log(url)


webRCX.send 29, parseInt(11000111, 2)