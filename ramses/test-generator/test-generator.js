const textarea = document.getElementById("file-content");
const header = `TESTES RANDOMICOS - github: @marcelobasso\n.c\nCasos de teste - 2023-2\n.m\n65535\n.l\n.d\n.p\n0`;
let n_tests = 50;
var line;
let string = [];

textarea.textContent = header;
for (let i = 0; i < n_tests; i++) {
    let step = randomValue(1, 25); // 1-25
    let operation = randomValue(0, 1); // 0 or 1
    let word_size = randomValue(0, 24); // 0-24, word size EXCLUDING the null char
    let source_end = randomValue(196, 255 - 2 * (word_size + 1)) // random start for the source
    let destination_end = randomValue(source_end + word_size + 1, 254 - word_size) // random start for the destination

    // generate header for the test
    textarea.textContent += `\n.t\n.c\n` +
        `Teste ${i + 1}\n` +
        `.i\n` +
        `192=${source_end}\n` +
        `193=${destination_end}\n` +
        `194=${step}\n` +
        `195=${operation}\n`;

    // generate string and store in source
    for (let j = 0; j < word_size; j++) {
        string[j] = randomValue(65, 90) // 65-90
        textarea.textContent += `${source_end + j}=${string[j]}\n`;
    }
    textarea.textContent += `${source_end + word_size}=0\n`; // adds null char

    // convert string
    string = string.map(char => {
        if (operation == 0) {
            char += step;
            char -= char > 90 ? 26 : 0;
        } else {
            char -= step;
            char += char < 65 ? 26 : 0;
        }

        return char;
    });

    textarea.textContent += `.o\n`;

    for (let k = 0; k < word_size; k++) {
        textarea.textContent += `${destination_end + k}=${string[k]}\n`;
    }
    textarea.textContent += `${destination_end + word_size}=0\n`; // adds null char
}

function randomValue(min, max) {
    return Math.floor(Math.random() * (max - min + 1) + min)
}