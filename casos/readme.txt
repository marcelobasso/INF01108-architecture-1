
(supondo que NÃO EXISTA o arquivo "a.in")
prog
- Informa arquivo de entrada não existente

(supondo que NÃO EXISTA o arquivo "filenf")
prog -i filenf
- Informa arquivo de entrada não existente

(supondo que EXISTA o arquivo "a.in")
prog
- Gera um arquivo a.out

prog -i in1.txt
- Gera um arquivo a.out

prog -o out1.txt -i in1.txt
- Gera um arquivo out1.txt

prog -i in1.txt -v 220 -o out1.txt
- Gera um arquivo out1.txt

prog -i in1.txt -v 110 -o out1.txt
- Informa erro no parâmetro "-v"

prog -i in2.txt
- Gera um arquivo a.out

prog -i in3.txt
- Informa erro na linha 3

prog -i in4.txt
- Informa erro na linha 2

prog -i in5.txt
- Informa erro na linha 2
- Informa erro na linha 3

prog -i in6.txt -v 220
- Gera arquivo a.out

prog -i in7.txt
- Gera arquivo a.out
- Há falta de tensão

prog -i in8.txt
- Gera arquivo a.out
- Há falta de tensão
- Informa 1:30 de medição


