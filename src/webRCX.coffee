this.webRCX = do ->

  opcodesToPackets = (opcodes)->
    packets = []
    packets[0] = 0x55 # header
    packets[1] = 0xff
    packets[2] = 0x00
    sum = 0
    i = 3
    for opcode,j in opcodes
      packets[i++] = opcode
      packets[i++] = ~opcode & 0xff
      sum += opcode
    packets[i++] = sum & 0xff
    packets[i++] = ~sum & 0xff
    packets

  packetsToBitEncoding = (packets)->
    bits = []
    for packet in packets
      bits.push 1 # start bit
      byte = []
      byteStr = packet.toString(2)
      for bitStr in byteStr
        byte.push Number bitStr
      while byte.length <8
        byte.unshift 0
      bits = bits.concat byte
      sum = byte.reduce (a,b)-> a+b
      parity = if sum%2 is 0 then 1 else 0
      bits.push parity # odd parity
      bits.push 1 # stop bit
    bits

  bitEncodingToPCMAry = do ->
    L = (t)-> 0xFFFF*( Math.sin(2*Math.PI*19200*t)+1)
    R = (t)-> 0xFFFF*(-Math.sin(2*Math.PI*19200*t)+1)
    zero = do ->
      ary = []
      i = 0
      while i/44100 < 8/19200
        ary[2*i]   = L(i/44100)
        ary[2*i+1] = R(i/44100)
        i++
      ary
    one = do -> 0 for i in zero
    (bits)->
      pcmAry = []
      console.log zero
      for bit in bits
        if bit is 0 then pcmAry = pcmAry.concat zero
        else             pcmAry = pcmAry.concat one
        pcmAry = pcmAry.concat zero
      pcmAry

  send: (ary...)->
    packets = opcodesToPackets ary
    bits = packetsToBitEncoding packets
    pcmAry = bitEncodingToPCMAry bits
    rawPCM = new Uint16Array pcmAry

    PCMData.encode
        sampleRate: 44100
        channelCount:   2
        bytesPerSample: 2
        data:      rawPCM
      ,(waveBuffer)->
        audio = document.createElement('audio')
        audio.src = 'data:audio/wav;base64,' + btoa waveBuffer
        audio.play()