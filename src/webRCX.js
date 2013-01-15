(function() {
  var __slice = [].slice;

  this.webRCX = (function() {
    var bitEncodingToPCMAry, opcodesToPackets, packetsToBitEncoding;
    opcodesToPackets = function(opcodes) {
      var i, j, opcode, packets, sum, _i, _len;
      packets = [];
      packets[0] = 0x55;
      packets[1] = 0xff;
      packets[2] = 0x00;
      sum = 0;
      i = 3;
      for (j = _i = 0, _len = opcodes.length; _i < _len; j = ++_i) {
        opcode = opcodes[j];
        packets[i++] = opcode;
        packets[i++] = ~opcode & 0xff;
        sum += opcode;
      }
      packets[i++] = sum & 0xff;
      packets[i++] = ~sum & 0xff;
      return packets;
    };
    packetsToBitEncoding = function(packets) {
      var bitStr, bits, byte, byteStr, packet, parity, sum, _i, _j, _len, _len1;
      bits = [];
      for (_i = 0, _len = packets.length; _i < _len; _i++) {
        packet = packets[_i];
        bits.push(1);
        byte = [];
        byteStr = packet.toString(2);
        for (_j = 0, _len1 = byteStr.length; _j < _len1; _j++) {
          bitStr = byteStr[_j];
          byte.push(Number(bitStr));
        }
        while (byte.length < 8) {
          byte.unshift(0);
        }
        bits = bits.concat(byte);
        sum = byte.reduce(function(a, b) {
          return a + b;
        });
        parity = sum % 2 === 0 ? 1 : 0;
        bits.push(parity);
        bits.push(1);
      }
      return bits;
    };
    bitEncodingToPCMAry = (function() {
      var L, R, one, zero;
      L = function(t) {
        return 0xFFFF * (Math.sin(2 * Math.PI * 19200 * t) + 1);
      };
      R = function(t) {
        return 0xFFFF * (-Math.sin(2 * Math.PI * 19200 * t) + 1);
      };
      zero = (function() {
        var ary, i;
        ary = [];
        i = 0;
        while (i / 44100 < 8 / 19200) {
          ary[2 * i] = L(i / 44100);
          ary[2 * i + 1] = R(i / 44100);
          i++;
        }
        return ary;
      })();
      one = (function() {
        var i, _i, _len, _results;
        _results = [];
        for (_i = 0, _len = zero.length; _i < _len; _i++) {
          i = zero[_i];
          _results.push(0);
        }
        return _results;
      })();
      return function(bits) {
        var bit, pcmAry, _i, _len;
        pcmAry = [];
        console.log(zero);
        for (_i = 0, _len = bits.length; _i < _len; _i++) {
          bit = bits[_i];
          if (bit === 0) {
            pcmAry = pcmAry.concat(zero);
          } else {
            pcmAry = pcmAry.concat(one);
          }
          pcmAry = pcmAry.concat(zero);
        }
        return pcmAry;
      };
    })();
    return {
      send: function() {
        var ary, bits, packets, pcmAry, rawPCM;
        ary = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        packets = opcodesToPackets(ary);
        bits = packetsToBitEncoding(packets);
        pcmAry = bitEncodingToPCMAry(bits);
        rawPCM = new Uint16Array(pcmAry);
        return PCMData.encode({
          sampleRate: 44100,
          channelCount: 2,
          bytesPerSample: 2,
          data: rawPCM
        }, function(waveBuffer) {
          var audio;
          audio = document.createElement('audio');
          audio.src = 'data:audio/wav;base64,' + btoa(waveBuffer);
          return audio.play();
        });
      }
    };
  })();

}).call(this);
