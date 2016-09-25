
import AESDefinitions::*;

//
// KeyExpansion module
//   Instantiates requisite number of round and buffers them
//




//
// KeyRound module
//   Produces one round of expanded key
//

module KeyRound #(parameter KEY_SIZE = 128,
                  parameter RCON_ITER = 1,
                  parameter KEY_BYTES = KEY_SIZE / 8,
                  parameter type key_t = byte_t [0:KEY_BYTES-1])

(input roundKey_t prevKey, output roundKey_t roundKey);

    int keyIdx;

    // substitution box 
    `ifdef INFER_RAM
    byte_t sbox[0:255];
    initial
    begin
      $readmemh("./src/mem/Sbox.mem", sbox);
    end
    `endif

    // book keeping
    localparam DWORD_SIZE = 4; /* chunk schedule_core operates on in bytes */

    always_comb
    begin
        /* copy last 4B of previous block */
        roundKey[0:DWORD_SIZE-1] = prevKey[KEY_BYTES-4:KEY_BYTES-1];
        /* perform core on the 4B block */
        roundKey[0:DWORD_SIZE-1] = schedule_core (roundKey[0:DWORD_SIZE-1], RCON_ITER);
        /* XOR with first 4B */
        roundKey[0:DWORD_SIZE-1] ^= prevKey[0:DWORD_SIZE-1];

        /* generate the rest of the round key from those first DWORD_SIZEB and the last round key */
        for (keyIdx = DWORD_SIZE; keyIdx < KEY_BYTES; keyIdx += DWORD_SIZE)
        begin
            /* copy last generated DWORD_SIZEB chunk to new key */
            roundKey[keyIdx +: DWORD_SIZE] = roundKey[keyIdx-DWORD_SIZE +: DWORD_SIZE];

            /* XOR with next DWORD_SIZEB from prev key */
            roundKey[keyIdx +: DWORD_SIZE] ^= prevKey[keyIdx +: DWORD_SIZE];
        end
    end

endmodule


//***************************************************************************************
// Core functionality
//***************************************************************************************

//
// ScheduleCore 
//   Inner loop of key expansion. Peformed once during each key expansion round
//

function automatic dword_t schedule_core(input dword_t in, integer round);

    dword_t out;

    out = rot4(in);
    out = sub4(out);
    out[0] ^= rcon(round);

    return out;
        
endfunction

//
// Rotate4
//   Rotates a 4 byte word 8 bits to the left
//

function automatic dword_t rot4 (input dword_t in);

    return {in[1], in[2], in[3], in[0]};

endfunction

//
// Substitute4 
//   Applies the sbox to a 4 byte word 
//

function automatic dword_t sub4(input dword_t in);

    dword_t out;
    for(int i=0; i<=3; ++i)
    begin
      `ifdef INFER_RAM
      out[i] = sbox[(in[i][7:4]*16) + in[i][3:0]];
      `else
      out[i] = sbox[in[i][7:4]][in[i][3:0]];
      `endif
    end
    return out;
    

endfunction

//
// Rcon 
//   Applies the rcon function to a byte 
//

function automatic byte_t rcon(input integer round);

    // rcon
    byte_t RCON[12] = '{'h8d, 'h01, 'h02, 'h04, 'h08, 'h10, 
                        'h20, 'h40, 'h80, 'h1b, 'h36, 'h6c};

    return (RCON[round]);

endfunction

