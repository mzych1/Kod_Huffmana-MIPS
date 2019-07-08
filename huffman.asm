#Projekt: kodowanie/dekodowanie Huffmanna
#Autor: Magdalena Zych
.data
  .align 2
  characters: .word 0:256 #tablica 256 4-bajtowych slow zainicjowanych zerem - licznosci poszczegolnych znakow
  tree: .space 4088 #miejsce na drzewo za pomoca ktorego tworzony bedzie kod huffmanna (511*8=max l. elementow*pamiec dla 1 el.)
  #pola elementu drzewa: licznosc/bity kodujace(2), znak (1), flaga/ilosc bitow kodujacych(1), left(2), right(2) 
  tmpWord: .space 4
  halfWord: .space 2
  
  .eqv outBufLen 64
  outBuffor: .space outBufLen
  
  inputFileAsk: .asciiz "\nPlik wejsciowy: "
  outputFileAsk: .asciiz "Plik wyjsciowy: "
  .eqv nameLength 32
  inFileName: .space nameLength
  outFileName: .space nameLength
  content: .space 1
  fileErrorMsg: .asciiz "Wystapil blad przy otwieraniu pliku\n"
  
  introLabel: .asciiz "-------Kodowanie/dekodowanie Huffmanna-------\nProsze wybrac opcje: [k]-kodowanie, [d]-dekodowanie\n"
  choice: .space 1
  choiceErrorLabel: .asciiz "Podano nieprawidlowy znak\n"
  printStatisticsLabel: .asciiz "------Statystyki wystapien znakow------ \nznak jako liczba calkowita - wystapienia\n"
  printCodesLabel: .asciiz "------Kody symboli------\nznak jako liczba calkowita - kod Huffmanna\n"
  headerErrorLabel: .asciiz "Wystapil blad przy odczytywaniu naglowka - plik wejsciowy jest zniszczony\n"
  decodingErrorLabel: .asciiz "Wystapil blad przy dekodowaniu pliku - plik wejsciowy jest zniszczony\n"
  
  #--------------$s0 - deskryptor pliku wejsciowego----------------------
  #--------------$s1 - liczba elementow w drzewie------------------------  
  #--------------$s2 - ilosc bitow kodujacych plik-----------------------
  #--------------$s3 - deskryptor pliku wyjsciowego----------------------
  #--------------$s4 - bity pisane do pliku przy kodowaniu---------------
  #--------------$s5 - wybor czy ma byc kodowanie czy dekodowanie--------
  #--------------$s6 - ilosc bajtow w buforze outBuffor------------------
  
.text
main:
  jal intro
  li $s6, 0
  beq $s5, 'd', decoding
coding:
  jal readInputFile
  jal printStatistics  #wyswietlanie statystyk wystapien i dodawanie elementow poczatkowych do drzewa
  #tworzenie drzewa huffmanna
  jal huffmannTree
  jal resetTreeBits #flaga, licznosc w drzewie -> zero
  #tworzenie kodow poprzez rekurencyjne przejscie drzewa
  move $a0, $s1
  li $a1, 2
  li $a2, 0
  li $a3, 0
  jal preorder 
  jal printCodes
  jal countBits # wynik w $s2
  jal openOutputFile
  jal writeOutputHeader #utworzenie naglowka + zapisywanie do tablicy characters wartosci: znak-ilosc bitow-bity kodujace
  jal codeFile
  jal closeOutputFile
  j exit
  
decoding: 
  jal openInputFile
  jal openOutputFile
    
  jal readHeader
  jal huffmannTree
  jal decodeFile
    
  #ponizsze funkcje nie sa konieczne do dekodowania pliku
  #umozliwiaja kontrole poprawnosci odczytu naglowka i budowy drzewa huffmanna
  #wyswietlenie statystyk wystapien znakow w pliku oryginalnym oraz przypisanych kodow
  jal printStatisticsDecoding
  jal resetTreeBits #flaga, licznosc w drzewie -> zero
  #tworzenie kodow poprzez rekurencyjne przejscie drzewa
  move $a0, $s1
  li $a1, 2
  li $a2, 0
  li $a3, 0
  jal preorder 
  jal printCodes
    
  jal closeOutputFile
  jal closeInputFile
  
  j exit
fileError:
  li $v0, 4
  la $a0, fileErrorMsg
  syscall
  
exit:
  li $v0, 10
  syscall #koniec funkcji glownej
###############################################
#funkcje:
readInputFile:
  addi $sp, $sp, -4
  sw $ra, 0($sp) #zapamietanie miejsca powrotu
  jal openInputFile
  la $s2, characters # adres tablicy characters
readFile:
  li $v0, 14
  move $a0, $s0
  la $a1, content
  li $a2, 1
  syscall #czytanie z pliku
  beqz $v0, readFileEnd #nie wczytano zadnego znaku - koniec pliku
  
  #aktualizacja tablicy characters
  la $t0, content
  lbu $t1, ($t0)
  sll $t1, $t1, 2 #4 bo to tablica liczb 4-bajtowych
  add $t1, $t1, $s2
  lw $t2, ($t1)
  addi $t2, $t2, 1
  sw $t2, ($t1)
  j readFile  
readFileEnd:
  jal closeInputFile  #zamkniecie pliku wejsciowego
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra

   
printStatistics:
  li $s1, 0 #liczba elementow w drzewie, poczatkowo 0
  li $v0, 4
  la $a0, printStatisticsLabel
  syscall
  li $t0, 0 #licznik
  la $t1, characters
  la $t3, tree
printStLoop: #uzywane rejestry: $t0, $t1, $t2, $t3, $t4, $5
  lw $t2, ($t1)
  addi $t0, $t0, 1
  addi $t1, $t1, 4 #4 bo to tablica liczb 4-bajtowych
  beqz $t2, doNotPrint
    
  #wypisywanie: znak w postaci liczbowej - licznosc
  li $v0, 1
  move $a0, $t0
  subi $a0, $a0, 1
  syscall #wypisanie znaku
  li $v0, 11
  li $a0, '-'
  syscall #wypisanie '-'
  li $v0, 1
  move $a0, $t2
  syscall #wypisanie licznosci
  li $v0, 11
  li $a0, '\n'
  syscall #nowa linia
    
  # dodawanie elementu do drzewa
  sll $t4, $s1, 3
  add $t4, $t4, $t3 #adres elementu
  sh $t2, ($t4) #zapamietanie licznosci
  subi $t5, $t0, 1
  sb $t5, 2($t4)#zapamietanie znaku
  sb $zero, 3($t4)
  sw $zero, 4($t4)
  addi $s1, $s1, 1 #element zostal dodany
    
doNotPrint:
  bne $t0, 256, printStLoop
  jr $ra #cala tablica zostala juz wypisana 
      
      
#indeksowanie od 1, 0 oznacza null
huffmannTree: #uzywane rejestry: $t0, $t1, $t2, $t3, $t4, $t5, $t5, $t6, $t7, $t8, $t9
  subi $t0, $s1, 1 #licznik, na koniec petli sprawdzenie czy jest = 0
treeLoop:
  li $t2, 0xFFFFFFF #najmniejsza znaleziona licznosc
  li $t4, 0  #numer elementu o najmniejszej licznosci
  li $t6, 1 #licznik
  la $t1, tree #adres drzewa
findLeastLoop1:
  #znajdowanie najmniejszej licznosci
  lhu $t7, ($t1) #aktualna licznosc
  lb $t8, 3($t1) #flaga
  seq $t8, $t8, $zero #element jest niewykorzystany
  slt $t9, $t7, $t2
  and $t8, $t8, $t9
  beqz $t8, Bigger1
  #ustawianie nowego $t2
  move $t2, $t7
  move $t4, $t6
Bigger1:
  addi $t1, $t1, 8
  addi $t6, $t6, 1 #zwiekszenie licznika
  ble $t6, $s1, findLeastLoop1
  #wszystkie elementy zostaly przejrzane pierwszy raz
  #ustawienie flagi znalezionego elementu, uzyte rejestry $t7,$t8
  sll $t7, $t4, 3
  subi $t7, $t7, 8
  la $t8, tree
  add $t7, $t7, $t8
  li $t8, 1
  sb $t8, 3($t7)
   
  li $t6, 1 #licznik
  la $t1, tree #adres drzewa
  li $t3, 0xFFFFFFF #najmniejsza znaleziona licznosc
  li $t5, 0 #numer elementu o najmniejszej licznosci
   
findLeastLoop2:
  #znajdowanie najmniejszej licznosci
  lhu $t7, ($t1) #aktualna licznosc
  lb $t8, 3($t1) #flaga
  seq $t8, $t8, $zero #element jest niewykorzystany
  slt $t9, $t7, $t3
  and $t8, $t8, $t9
  beqz $t8, Bigger2
  #ustawianie nowego $t2
  move $t3, $t7
  move $t5, $t6
Bigger2:
  addi $t1, $t1, 8
  addi $t6, $t6, 1 #zwiekszenie licznika
  ble $t6, $s1, findLeastLoop2
  #wszystkie elementy zostaly przejrzane 2 raz
  #ustawienie flagi znalezionego elementu, uzyte rejestry $t7,$t8
  sll $t7, $t5, 3
  subi $t7, $t7, 8
  la $t8, tree
  add $t7, $t7, $t8
  li $t8, 1
  sb $t8, 3($t7)
      
  #dodawanie elementu do drzewa
  addi $s1, $s1, 1 #zwiekszenie liczby elementow w drzewie
  subi $t0, $t0, 1 #zmniejszenie licznika
  
  sll $t7, $s1, 3 #bylo $t5 zamiast $s1
  la $t8, tree
  add $t7, $t7, $t8 #adres nowego elementu
  subi $t7, $t7, 8
  add $t6, $t2, $t3
    
  sh $t6, ($t7) #zapisanie licznosci nowego elementu
  sh $zero, 2($t7) #wyzerowanie znaku i flagi nowego elementu
  sh $t4, 4($t7) #zapisanie left nowego elementu
  sh $t5, 6($t7) #zapisanie right nowego elementu
  bne $t0, $zero, treeLoop
  #dodano juz wszystkie elementy
  jr $ra
  
  
resetTreeBits: 
  la $t0, tree
  li $t1, 0 #licznik
resetBitsLoop:
  sh $zero, ($t0)
  sb $zero, 3($t0)
  addiu $t0, $t0, 8
  addiu $t1, $t1, 1
  bne $t1, $s1, resetBitsLoop
  jr $ra


preorder:  # $a0 -> nr wierzcholka dla ktorego zostala wywolana funkcja, $a1 -> tryb wywolania (root, lewy, czy prawy)
  addi $sp, $sp, -16 #zapisanie potrzebnych pozniej wartosci, dalej zapisane: licznosc bitow i bity kodujace
  sw $ra, 0($sp)
  sw $a0, 4($sp)
  sw $zero, 8($sp)# w razie czego zeby byl ten fragment wyzerowany
  sw $zero, 12($sp)# w razie czego zeby byl ten fragment wyzerowany
  #ustalenie adresu aktualnego elementu
  la $t0, tree
  subi $t1, $a0, 1
  sll $t1, $t1, 3
  add $t1, $t1, $t0
  
  beq $a1, 2, nicNieDopisuj
  #cos bedzie dopisywane - zwieksz ilosc bitow
  addi $t2, $a2, 1 #zwikszenie ilosci bitow
  sb $t2, 3($t1)
  sw $t2, 8($sp)#zapisanie na stosie
  beq $a1, 1, dopisz1
  beq $a1, 0, dopisz0
dopisz1:
  sll $t2, $a3, 1
  ori $t2, $t2, 1
  sh $t2, ($t1)
  sw $t2, 12($sp) #zapis na stosie
  j nicNieDopisuj
dopisz0:
  sll $t2, $a3, 1
  sh $t2, ($t1)
  sw $t2, 12($sp) #zapis na stosie 
nicNieDopisuj:
  lhu $t2, 4($t1) #wczytanie left
  beq $t2, $zero, brakLewegoPotomka
  #wywolywanie preorder dla lewego potomka
  move $a0, $t2
  li $a1, 0
  lw $a2, 8($sp)
  lw $a3, 12($sp)
  jal preorder
brakLewegoPotomka:
  #lepiej zaktualizowac $t1 adres z ktorego pobieramy wartosci elementu, bo preorder moglo byc wywolywane dla lewego potomka
  lw $a0, 4($sp) 
  lw $a2, 8($sp) 
  lw $a3, 12($sp)
  la $t0, tree
  subi $t1, $a0, 1
  sll $t1, $t1, 3
  add $t1, $t1, $t0
  #sprawdzanie czy trzeba wywolywac preorder dla prawego potomka
  lhu $t2, 6($t1) #wczytanie right
  beq $t2, $zero, brakPrawegoPotomka
  #wywolywanie preorder dla prawego potomka
  move $a0, $t2
  li $a1, 1
  jal preorder
brakPrawegoPotomka:
  #koniec funkcji - odczytanie potrzebnych dla funkcji wywolujacej wartosci
  lw $ra, 0($sp)
  lw $a0, 4($sp)
  lw $a2, 8($sp)
  lw $a3, 12($sp)
  addi $sp, $sp, 16
  jr $ra
 
 
printCodes: #uzyte rejestry: $t0, $t1, $t2, $t3, $t4
  li $v0, 4
  la $a0, printCodesLabel
  syscall
  
  addi $t0, $s1, 1
  div $t0, $t0, 2 #$t0 - licznik = ilosc lisci (kodowanych znakow)
  la $t1, tree
printCodesLoop:
  li $v0, 1
  lbu $a0, 2($t1)
  syscall
  li $v0, 11
  li $a0, '-'
  syscall
  #pisanie kodu w petli
  lbu $t2, 3($t1)
  lhu $t3, ($t1)
WriteBitLoop:
  subi $t2, $t2, 1 #tyle razy trzeba przesunac o 1 w prawo
  move $t5, $t3
  srlv $t5, $t5,$t2
  and $t5, $t5, 1
  li $v0, 1
  move $a0, $t5
  syscall#wypisanie 1 bita
  bnez $t2, WriteBitLoop
  
  li $v0, 11
  li $a0, '\n'
  syscall
    
  addi $t1, $t1, 8
  subi $t0, $t0, 1
  bnez $t0, printCodesLoop 
  jr $ra
  
  
countBits: #uzyte rejestry: $t0, $t1, $t2, $t3, $t4, $t5
  li $s2, 0
  addi $t0, $s1, 1
  div $t0, $t0, 2 #$t0 - licznik = ilosc lisci (kodowanych znakow)
  la $t1, tree
  la $t3, characters
countBitsLoop:
  lbu $t2, 2($t1)
  sll $t2, $t2, 2
  add $t2, $t2, $t3 
  lw $t4, ($t2) #licznosc znaku
  
  lbu $t5, 3($t1) #ilosc bitow kodujacych
  mul $t4, $t4, $t5
  add $s2, $s2, $t4
   
  subi $t0, $t0, 1
  addi $t1, $t1, 8
  bnez $t0, countBitsLoop
  jr $ra
  
      
openOutputFile:
  li $v0, 13
  la $a0, outFileName 
  li $a1, 1 #write only - open mode
  syscall #otworzenie pliku - deskryptor w $v0
  move $s3, $v0 #deskryptor pliku - $s3
  bltz $s3, fileError #niepowodzenie przy otwieraniu pliku
  jr $ra


openInputFile:
  li $v0, 13
  la $a0, inFileName 
  li $a1, 0 #read only - open mode
  syscall #otworzenie pliku - deskryptor w $v0
  move $s0, $v0 #deskryptor pliku - $s0
  bltz $s0, fileError #niepowodzenie przy otwieraniu pliku
  jr $ra
  
  
writeOutputHeader: #uzyte rejestry: $t0, $t1, $t2, $t3, $t4, $t5
  move $a0, $s3 #wartosc stala na cala funkcje
  #ilosc kodowanych znakow - 2 bajty
  li $v0, 15
  la $a1, halfWord
  li $a2, 2
  addi $t0, $s1, 1
  div $t0, $t0, 2
  sh $t0, ($a1)
  syscall
  #dla kazdego kodowanego znaku: znak (1 bajt) + ilosc bitow (1 bajt) + bity kodujace dopelnione zerami do 16 (2 bajty)
  la $t1, tree #adres aktualnego elementu
  la $t3, characters
headerLoop:
  #obliczanie adresu danego znaku w tablicy characters
  lbu $t4, 2($t1)
  sll $t4, $t4, 2
  add $t4, $t4, $t3
   
  li $v0, 15
  addi $a1, $t1, 2
  li $a2, 1
  syscall #zapis znaku (1 bajt)
    
  li $v0, 15
  move $a1, $t4 
  li $a2, 2
  syscall#zapis licznosci danego znaku (2 bajty)
    
  #przy okazji - zapisywanie do tablicy characters wartosci: znak-ilosc bitow-bity kodujace
  lw $t5, ($t1)
  sw $t5, ($t4)
    
  addi $t1, $t1, 8
  subi $t0, $t0, 1
  bnez $t0, headerLoop
  #ilosc bitow kodujacych plik (4 bajty)
  li $v0, 15
  la $a1, tmpWord
  sw $s2, ($a1)
  li $a2, 4
  syscall
  jr $ra
  
  
codeFile: #uzyte rejestry: $t0, $t1, $t2, $t3, $t4, $t5
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  #otworzenie pliku wejsciowego
  jal openInputFile

  la $t1, characters
  li $t0, 8 #licznik bitow ktore mozna jeszcze zapisac i beda zapisywane do pliku wyjsciowego jako 1 bajt
  li $s4, 0 # rejestr z bitami ktore beda pisane do pliku wyjsciowego
  #czytanie pliku po 1 znaku do momentu az nie zostanie wczytany zaden znak
readFile2:
  li $v0, 14
  move $a0, $s0
  la $a1, content
  li $a2, 1
  syscall #czytanie z pliku
  beqz $v0, readFileEnd2 #nie wczytano zadnego znaku - koniec pliku
  
  #kodowanie
  la $t2, content
  lbu $t2, ($t2)
  sll $t2, $t2, 2
  add $t2, $t2, $t1
  lbu $t3, 3($t2)
  lhu $t4, ($t2) 
  
  li $t5, 16
  sub $t5, $t5, $t3 # tyle razy trzeba zrobic shift left na rejestrze 
  sllv $t4, $t4, $t5 # $t5 juz wolne
writeCodingBit:
  andi $t5, $t4, 0x8000
  sne $t5, $t5, $zero
  sll $s4, $s4, 1
  or $s4, $s4, $t5 # $t5 juz wolne
  subi $t0, $t0, 1
  bnez $t0, continue
  jal writeByte
continue:
  sll $t4, $t4, 1
  subi $t3, $t3, 1
  bnez $t3, writeCodingBit
    
  j readFile2  
readFileEnd2:  
  li $t7, 8
  beq $t0, $t7, noMoreBitsToWrite
  sllv $s4, $s4, $t0
  jal writeByte
noMoreBitsToWrite:
  beqz $s6, emptyBuffor
  jal writeBuffor #zapisanie do pliku wyjsciowego niedopelnionego bufora
emptyBuffor:
  #koniec kodowania - zamkniecie pliku wejsciowego
  jal closeInputFile
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra
  
  
closeOutputFile:
  move $a0, $s3 #deskryptor pliku
  li $v0, 16
  syscall #zamkniecie pliku
  jr $ra


closeInputFile:
  move $a0, $s0 #deskryptor pliku
  li $v0, 16
  syscall #zamkniecie pliku
  jr $ra
  
      
writeByte:
  #zapis bajtu do bufora
  la $t8, outBuffor
  add $t8, $t8, $s6
  sb $s4, ($t8)
  addi $s6, $s6, 1
  bne $s6, outBufLen, doNotWriteBuffor
  #zapis bufora do pliku
writeBuffor:
  li $v0, 15
  move $a0, $s3
  la $a1, outBuffor
  move $a2, $s6
  syscall
  li $s6, 0
doNotWriteBuffor:
  li $s4, 0# zresetowanie odpowiednich wartosci
  li $t0, 8
  jr $ra

intro:
  li $v0, 4
  la $a0, introLabel 
  syscall
  li $v0, 8
  la $a0, choice
  li $a1, 2
  syscall
  lbu $s5, ($a0)
  seq $t0, $s5, 'k'
  seq $t1, $s5, 'd'
  or $t0, $t0, $t1
  beqz $t0, choiceError
  
  #wczytanie nazwy piku wejsciowego
  li $v0, 4
  la $a0, inputFileAsk
  syscall
  
  li $v0, 8
  la $a0, inFileName
  li $a1, nameLength
  syscall #wczytanie nazwy pliku
  move $t0, $a0
changeLastSignLoop1:
  lb $t1, ($t0)
  addi $t0, $t0, 1
  bne $t1, '\n', changeLastSignLoop1
  sb $zero, -1($t0) #zmiana ostatniego znaku '\n' --> 0
  
  #wczytanie nazwy piku wyjsciowego
  li $v0, 4
  la $a0, outputFileAsk
  syscall
  
  li $v0, 8
  la $a0, outFileName
  li $a1, nameLength
  syscall #wczytanie nazwy pliku
  move $t0, $a0
changeLastSignLoop2:
  lb $t1, ($t0)
  addi $t0, $t0, 1
  bne $t1, '\n', changeLastSignLoop2
  sb $zero, -1($t0) #zmiana ostatniego znaku '\n' --> 0
  j endIntro
choiceError:
  li $v0, 4
  la $a0, choiceErrorLabel
  syscall
  j exit
endIntro:
  jr $ra
  
  
readHeader:
  move $a0, $s0 #wartosci nadane dla calej funkcji
  la $a1, content
  li $a2, 1
  #odczyt ilosci kodowanych znakow
  li $v0, 14
  syscall #odczyt mlodszego bajtu
  beqz $v0, headerError
  lbu $t0, ($a1)
  
  li $v0, 14
  syscall #odczyt starszego bajtu
  beqz $v0, headerError
  lbu $t1, ($a1)
  sll $t1, $t1, 8
  or $t0, $t0, $t1 #$t0 - ilosc znakow ktorych kody trzeba teraz odczytac
  
  la $t1, tree
  li $s1, 0
readSignAndCodeLoop: #czytanie znaku i licznosci i dodawanie elementow poczatkowych do drzewa
  li $v0, 14
  syscall #odczyt znaku
  beqz $v0, headerError
  lbu $t2, ($a1)
  sb $t2, 2($t1) #zapis znaku w elemencie drzewa
   
  li $v0, 14
  syscall #odczyt 8 mlodszych bitow licznosci
  beqz $v0, headerError
  lbu $t2, ($a1)
  sb $t2, 0($t1) #zapis mlodszych bitow w elemencie drzewa
    
  li $v0, 14
  syscall #odczyt 8 starszych bitow licznosci
  beqz $v0, headerError
  lbu $t2, ($a1)
  sb $t2, 1($t1) #zapis starszych bitow w elemencie drzewa
    
  sb $zero, 3($t1) #wyzerowanie flagi
    
  addi $s1, $s1, 1
  addi $t1, $t1, 8
  subi $t0, $t0, 1
  bnez $t0, readSignAndCodeLoop
    
  #czytanie ilosci bitow kodujacych plik
  li $v0, 14
  la $a1, tmpWord
  li $a2, 4
  syscall
  lw $s2, ($a1)    
  j readHeaderEnd
headerError:
  li $v0, 4
  la $a0, headerErrorLabel
  syscall
  jal closeInputFile
  jal closeOutputFile
  j exit
readHeaderEnd:
  jr $ra
  
  
decodeFile:
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  move $t0, $s1 #aktualny wierzcholek - na poczatku korzen
  la $t1, tree
readCodedByte:
  li $v0, 14
  move $a0, $s0
  la $a1, content
  li $a2, 1
  syscall #czytanie po 1 bajcie
  beqz $v0, decodeFileEnd #koniec pliku
  lbu $t2, ($a1) #wczytany bajt
  li $t3, 8
readCodedBitLoop:
  andi $t4, $t2, 128 #$t4- przetwarzany bit
  sne $t4, $t4, $zero
  sll $t2, $t2, 1 #przesuniecie aktualnego bajtu o 1 w lewo
  sll $t5, $t0, 3
  subi $t5, $t5, 8 
  add $t5, $t5, $t1 #adres aktualnego wierzcholka
   
  beqz $t4, goToLeftSon
  beq $t4, 1, goToRightSon
goToLeftSon:
  lhu $t0, 4($t5) #nowy aktualny wierzcholek
  j sonDone
goToRightSon:
  lhu $t0, 6($t5) #nowy aktualny wierzcholek
sonDone:
  beqz $t0, decodingError
  sll $t5, $t0, 3
  subi $t5, $t5, 8 
  add $t5, $t5, $t1 #adres aktualnego wierzcholka
  lb $t6, 4($t5)
  seq $t6, $t6, $zero
  lb $t7, 6($t5)
  seq $t7, $t7, $zero
  and $t6, $t6, $t7 # $t6=1 gdy aktualny element jest lisciem
  beqz $t6, doNotWriteByte
      
  #jak $t6 jest lisciem to wczytujemy aktualny znak i wpisujemy go do bufora
  la $t8, outBuffor
  add $t8, $t8, $s6
  lbu $t9, 2($t5)
  sb $t9, ($t8)
  addi $s6, $s6, 1
  move $t0, $s1 #aktualnym elementem staje sie korzen
  bne $s6, outBufLen, doNotWriteByte  
  #wypisanie bufora do pliku wyjsciowego
  li $v0, 15
  move $a0, $s3
  la $a1, outBuffor
  move $a2, $s6
  syscall #wpisanie bufora do pliku wyjsciowego
  li $s6, 0
doNotWriteByte:
  subi $t3, $t3, 1
  subi $s2, $s2, 1
  beqz $s2, decodeFileEnd #przetworzono juz wszystkie bity kodujace
  bnez $t3, readCodedBitLoop #nie przetworzono jeszcze wszystkich 8 bitow ze wczytanego bajtu
  j readCodedByte #trzeba wczytac kolejny bajt  
  j decodeFileEnd
decodingError:
  li $v0, 4
  la $a0, decodingErrorLabel
  syscall
  jal closeInputFile
  jal closeOutputFile
  j exit
decodeFileEnd:
  beqz $s6, emptyBufforDecoding
  li $v0, 15
  move $a0, $s3
  la $a1, outBuffor
  move $a2, $s6
  syscall #wpisanie niedopelnionego bufora do pliku wyjsciowego
emptyBufforDecoding:
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


printStatisticsDecoding:
  addi $t0, $s1, 1
  div $t0, $t0, 2
  la $t1, tree
  
  li $v0, 4
  la $a0, printStatisticsLabel
  syscall
prStatDecLoop:
  lbu $a0, 2($t1) #znak
  li $v0, 1
  syscall#wypisanie znaku
  
  li $a0, '-'
  li $v0, 11
  syscall #wypisanie '-'
   
  lhu $a0, ($t1)
  li $v0, 1
  syscall #wypisanie licznosci
    
  li $a0, '\n'
  li $v0, 11
  syscall #nowa linia
    
  addi $t1, $t1, 8
  subi $t0, $t0, 1
  bnez $t0, prStatDecLoop
  
  jr $ra
