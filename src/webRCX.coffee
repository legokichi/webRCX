this.webRCX = do ->

  console.log "testing..."

  opcodesToPackets = (opcodes)->
    commands = opcodes
      .map((_)-> [_ & 0xff, ~_ & 0xff])
      .reduce (rslts, [a, b])-> rslts.concat(a, b)
    sum = opcodes
      .reduce (rslt, _)-> (rslt + _) & 0xff

    [
      0x55 # leader
      0xff # header
      0x00 # ~header
    ].concat commands, [sum & 0xff, ~sum & 0xff]

  console.assert(
    opcodesToPackets([12, 255]).every (v, i)->
      v is [85, 255, 0, 12, 243, 255, 0, 11, 244][i])


  packetsToBitEncoding = (packets)->
    packets.map (packet)->
      byte = (Number v for v in packet.toString(2))
      while byte.length <8
        byte.unshift 0
      sum = byte.reduce (a, b)-> a + b
      parity = if sum % 2 is 0 then 1 else 0
      [
        1 # start bit
      ].concat byte, [
        parity # odd parity bit
        1 # stop bit
      ]

  console.assert(
    packetsToBitEncoding(
      opcodesToPackets([255, 254]))
    [0].every (v, i)->
      v is [1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1][i])


  console.log "ok."


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
        console.dir waveBuffer
        blob = new Blob(waveBuffer, {type: "data:audio/wav"})
        url = URL.createObjectURL(blob);
        console.log url
        audio = document.createElement('audio')
        audio.src = 'data:audio/wav;base64,' + btoa waveBuffer
        audio.play()