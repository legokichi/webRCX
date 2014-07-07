class Logging
  log: (str)->
    console.log str
    console.log @
    @

  watch: (fn)->
    fn.call @
    @

  manipulate: (fn)->
    fn.call @

class Bytes extends Logging

  constructor: (args)->
    @value = new Uint8Array(args)

  writeInt8: (offset, value)->
    u8 = new Uint8Array(@value)
    u8[offset] = value & 0xff
    new @constructor(u8)

  writeInt16: (offset, value)->
    u8 = new Uint8Array(@value)
    u8[offset] = value & 0xff
    value >>>= 8
    u8[offset + 1] = value & 0xff
    new @constructor(u8)

  writeInt32: (offset, value)->
    u8 = new Uint8Array(@value)
    u8[offset] = value & 0xff
    value >>>= 8
    u8[offset + 1] = value & 0xff
    value >>>= 8
    u8[offset + 2] = value & 0xff
    value >>>= 8
    u8[offset + 3] = value & 0xff
    new @constructor(u8)

  writeString: (offset, str)->
    u8 = new Uint8Array(@value)
    for i in [0...str.length]
      u8[offset + i] = str.charCodeAt(i)
    new @constructor(u8)

  writeArray: (offset, ary)->
    u8 = new Uint8Array(@value)
    for i in [offset...offset+ary.length]
      u8[i] = ary[i-offset]
    new @constructor(u8)

  toUint8Array: ->
    u8 = new Uint8Array(@value)
    for i in [0...@value.length]
      u8[i] = @value[i]
    u8


class PCM extends Bytes

  constructor: (sampleRate, channel, bitsPerSample, u8)->
    blockAlign = channel * (bitsPerSample / 8)
    byteRate = sampleRate * blockAlign
    @value = new Bytes(44 + u8.length)
      .writeString( 0, "RIFF")        # Chunk ID
      .writeInt32(  4, 44+u8.length-8)# Chunk Size
      .writeString( 8, "WAVE")        # Format
      .writeString(12, "fmt ")        # Subchunk 1 ID
      .writeInt32( 16, 16)            # Subchunk 1 Size
      .writeInt16( 20, 1)             # Audio Format
      .writeInt16( 22, channel)       # Num Channels
      .writeInt32( 24, sampleRate)    # Sample Rate (Hz)
      .writeInt32( 28, byteRate)      # Byte Rate (サンプリング周波数 * ブロックサイズ)
      .writeInt16( 32, blockAlign)    # Block Align (チャンネル数 * 1サンプルあたりのビット数 / 8)
      .writeInt16( 34, bitsPerSample) # Bits Per Sample
      .writeString(36, "data")        # Subchunk 2 ID
      .writeInt32( 40, u8.length)     # Subchunk 2 Size
      .writeArray( 44, u8)            # PCM Raw Data
      .toUint8Array()

  toBlob: ->
    new Blob([@value], {type: "audio/wav"})

  toURL: ->
    URL.createObjectURL(@toBlob())

  toAudio: ->
    audio = document.createElement("audio")
    audio.src = @toURL()
    audio


class Opcode extends Logging

  constructor: (commands)->
    code = commands
      .map((_)-> [_ & 0xff, ~_ & 0xff])
      .reduce(((ary, [a, b])-> ary.concat(a, b)), [])
    sum = commands
      .reduce (sum, _)-> (sum + _) & 0xff
    @value = [
      0x55 # leader
      0xff # header
      0x00 # ~header
    ].concat code, [sum & 0xff, ~sum & 0xff]

  toPackets: ->
    new Packets(@value)


class Packets extends Logging

  constructor: (ary)-> 
      @value = ary.map (_)-> new Packet _

  toPCM: ->
    data = @value
      .map((packet)->
        packet
          .toPCMData())
      .reduce(((ary, _)-> ary.concat(_)), [])
    new PCM(38400, 2, 8, data)


class Packet extends Logging

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

  PULSE = [0..7]
    .map(-> [0xFF, 0x00, 0x00, 0xFF])
    .reduce(((ary, _)-> ary.concat(_)), [])
  NOTHING = PULSE.map -> 0x80
  GAP = []

  toPCMData: ->
    @value
      .map((bit)-> if bit is 1 then NOTHING else PULSE)
      .reduce(((ary, _)-> ary.concat(_)), [])
      .concat GAP


console.log new Opcode([29, parseInt(11000111, 2)])
  .toPackets()
  .watch(->
    console.log @value
      .map((packet)-> packet.value)
      .reduce(((ary, _)-> ary.concat(_)), [])
    @)
  .toPCM()
  .toURL()