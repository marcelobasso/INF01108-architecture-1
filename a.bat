rem Script para MONTAR arquivos .ASM
rem Ex: Para montar o arquivo "teste.asm", deve-se usar a linha de comando
rem a <arquivo-fonte>
rescan
masm /Zi %1.asm,%1.obj,%1.lst,%1.crf;
