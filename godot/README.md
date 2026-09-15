# Protocol Zero — Godot 3D Rebuild

Esta pasta inicia a migração visual do protótipo HTML para um jogo 3D estilizado.

## Direção

- Engine: Godot 4.x
- Câmera: 3/4 isométrica/ortográfica
- Arte: stylized semi-realistic mobile survival
- Referência de sensação: estratégia mobile premium, adaptada ao bunker CZI-07
- Plataforma alvo: mobile primeiro, PC para desenvolvimento e teste

## Primeiro vertical slice

Cena: `scenes/czi07_dormitory.tscn`

Objetivo da cena:
- provar volume real;
- provar iluminação com sombra;
- provar leitura 3/4;
- provar que a sala pode parecer habitada;
- manter a primeira tensão narrativa: 4 leitos para 5 pessoas.

O blockout atual usa primitivas procedurais. Ele NÃO é a arte final. Depois da aprovação da câmera/escala, os placeholders serão substituídos por modelos estilizados, materiais e props finais.

## Próximos passos

1. Validar câmera, escala e composição no PC.
2. Criar kit modular CZI-07: parede, piso, porta, tubulação, luz e painel.
3. Criar modelos/props do dormitório.
4. Integrar os cinco cidadãos em 3D.
5. Adicionar navegação e pontos de interação.
6. Recriar gerador, refeitório, corredor e Setor B.
7. Só depois reconectar comportamento, memória e sistema social.

## Rodar

Abra a pasta `godot/` no Godot 4.x e execute o projeto.
