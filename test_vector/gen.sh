#!/bin/bash
#
# Aes test vector generation using openssl.
# Input and aes output is stored to file.

# number of tests to be generated
TEST_NUM=1

# file names
IN_FILE="data_i.txt"
OUT_FILE="aes_enc_data_o.txt"
KEY_FILE="aes_enc_key_i.txt"

# input vector size 
SIZE=128


function gen_rand_hex {

local chars='01'
#local chars='ABCDEF0123456789'

local str=""
for ((i = 0; i < $1 ; i++)); do
    str+=${chars:RANDOM%${#chars}:1}
    # alternatively, str=$str${chars:RANDOM%${#chars}:1} also possible
done
echo $str
}


# init
in=""
key=""
tmp="/tmp/$(gen_rand_hex "8")"
zero=00000000000000000000000000000000
var=""
# remove and create files
touch ${tmp}
rm ${IN_FILE}
rm ${OUT_FILE}
rm ${KEY_FILE}
for((i = 0; i < $TEST_NUM; i++)); do  
	# generate input file
	in=$(gen_rand_hex "128")
	#generate key
	key=$(gen_rand_hex "128")
	# generate aes output
	echo ${in} | openssl aes128 -inform der -outform der -a -e -K ${key} -iv ${zero} -out ${tmp}
	#log
	echo "in $in key $key out $tmp"
	# write to file, use bc to convert hex to binary 
	var=$(cat $tmp)
	echo "result : '$var'"
	echo $(cat $tmp | xxd -b | awk -F " " '{print $2 $3 $4 $5 $6 }' | tr -d "\n") >> ${OUT_FILE}
	#echo $(echo $in | xxd -b | awk -F " " '{print $2 $3 $4 $5 $6 }' | tr -d "\n") >> ${OUT_FILE}
	#echo $(echo $key | xxd -b | awk -F " " '{print $2 $3 $4 $5 $6 }' | tr -d "\n") >> ${OUT_FILE}
	echo 'ibase=16; obase=2; '${in}  | BC_LINE_LENGTH=0 bc >> ${IN_FILE}
	echo 'ibase=16; obase=2; '${key} | BC_LINE_LENGTH=0 bc >> ${KEY_FILE}
done

#output - read files
echo "$IN_FILE :"
cat ${IN_FILE}
echo "$KEY_FILE :"
cat ${KEY_FILE}
echo "$OUT_FILE :"
cat ${OUT_FILE}

# convert to binary
