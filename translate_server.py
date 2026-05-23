#!/usr/bin/env python3
"""
translate_server.py — Servidor local de tradução EN→PT para o KH1 Text Editor
Motor: Helsinki-NLP/opus-mt-tc-big-en-pt (MarianMT, ~300 MB, offline após 1ª carga)

Instalar dependências:
  pip install flask transformers sentencepiece torch

Uso:
  python translate_server.py

O app Flutter chama:
  GET  http://127.0.0.1:7654/health
  POST http://127.0.0.1:7654/translate
    Body:  {"texts": ["string1", "string2"]}
    Reply: {"translations": ["tradução1", "tradução2"]}
"""

import re
import sys
from flask import Flask, request, jsonify
from transformers import MarianMTModel, MarianTokenizer

MODEL_NAME = "Helsinki-NLP/opus-mt-tc-big-en-pt"
PORT = 7654

# Termos do universo KH que NÃO devem ser traduzidos
PROTECTED_TERMS = [
    "Kingdom Hearts", "Hollow Bastion", "Traverse Town", "End of the World",
    "Destiny Islands", "Disney Castle", "Deep Jungle",
    "Keyblade", "Heartless", "Nobody", "Final Mix",
    "Sora", "Riku", "Kairi", "Donald", "Mickey", "Ansem", "Xehanort",
    "Olympus", "Agrabah", "Monstro", "Atlantica", "Neverland",
    "Aladdin", "Jasmine", "Alice", "Belle", "Aurora", "Cinderella", "Snow White",
    "Ariel", "Wendy", "Peter Pan", "Tinker Bell", "Captain Hook", "Maleficent",
    "Pooh", "Piglet", "Eeyore", "Rabbit", "Roo", "Kanga", "Tigger",
]

# Nomes com tradução específica PT-BR
CHAR_TRANSLATIONS = {
    "Goofy": "Pateta",
    "Attack": "Atacar",
    "Items": "Itens",
}

app = Flask(__name__)
tokenizer = None
model = None


def protect(text: str) -> tuple:
    """Substitui termos protegidos e tokens de controle por placeholders."""
    ph = {}
    idx = 0

    # Códigos de controle [C:XX], [BTN:XX], [?:XX], [ACC:XX] — preservar verbatim
    code_re = re.compile(r'\[(?:C|BTN|\?|ACC):[\dA-Fa-f]{2}\]')
    def sub_code(m):
        nonlocal idx
        key = f"__X{idx}__"
        ph[key] = m.group(0)
        idx += 1
        return key
    text = code_re.sub(sub_code, text)

    # Traduções específicas de personagens antes de proteger nomes
    for en, pt in CHAR_TRANSLATIONS.items():
        text = text.replace(en, pt)

    # Termos protegidos (mais longos primeiro para evitar conflito de substring)
    for term in sorted(PROTECTED_TERMS, key=len, reverse=True):
        if term in text:
            key = f"__P{idx}__"
            ph[key] = term
            text = text.replace(term, key)
            idx += 1

    return text, ph


def restore(text: str, ph: dict) -> str:
    for key, original in ph.items():
        text = text.replace(key, original)
    return text


def translate_line(line: str) -> str:
    if not line.strip():
        return line
    protected, ph = protect(line)
    inputs = tokenizer(
        [protected], return_tensors="pt",
        padding=True, truncation=True, max_length=512,
    )
    output = model.generate(**inputs, num_beams=4, max_length=512)
    result = tokenizer.decode(output[0], skip_special_tokens=True)
    return restore(result, ph)


def translate_text(text: str) -> str:
    # EVDL: strings com \n são bolhas de 2 linhas — traduzir cada linha separado
    # para manter o tamanho controlado por slot
    lines = text.split("\n")
    return "\n".join(translate_line(line) for line in lines)


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "model": MODEL_NAME})


@app.route("/translate", methods=["POST"])
def translate():
    data = request.get_json(force=True)
    texts = data.get("texts", [])
    results = []
    for text in texts:
        try:
            results.append(translate_text(text))
        except Exception as e:
            print(f"[ERRO] {e}", file=sys.stderr)
            results.append(text)  # fallback: retorna original sem traduzir
    return jsonify({"translations": results})


if __name__ == "__main__":
    print(f"Carregando {MODEL_NAME} ...")
    print("(Primeira execução: ~300 MB de download automático — aguarde)")
    tokenizer = MarianTokenizer.from_pretrained(MODEL_NAME)
    model = MarianMTModel.from_pretrained(MODEL_NAME)
    print(f"Modelo pronto. Servidor rodando em http://127.0.0.1:{PORT}")
    app.run(host="127.0.0.1", port=PORT, threaded=True)
