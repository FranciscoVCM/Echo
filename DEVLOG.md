# DEVLOG — Echo (cópia de trabalho do Francisco)

## Como está organizado este repositório

- `ECHO/` — projeto Godot 4.6.2 (abre `ECHO/project.godot`). Veio do `echo.zip` do colega; os ficheiros originais estão no commit `Baseline` sem alterações.
- `docs/` — design atual, auditoria, roadmap e o prompt inicial.
- `reference/` — PDFs da cadeira e trabalhos A2–A7 (só local, **não** vai para o git: ~135 MB).
- A pasta do colega (`Downloads/echo`) **não foi alterada**. Só usei o executável do Godot que lá está para correr testes.
- Git só local (não há remote). Nada foi enviado para lado nenhum.

---

## 2026-11-22 — Fatia vertical: "Clareira"

### O que foi feito
Uma cena nova, jogável à parte, onde o Ping é comunicação e exploração (sem minijogos):
`ECHO/scenes/world/clearing_slice.tscn` (no editor: abrir a cena e carregar **F6**).

| Encontro | Blob(s) | O que é preciso perceber |
|---|---|---|
| Tutorial | Fá (verde) | A cor é uma nota. Nota errada → a blob responde com a sua nota (som + onda colorida) e o nome aparece. |
| Tímida | Dó (vermelho), canto superior esquerdo | O Dó acorda-a; depois **5 s sem pings**. Qualquer ping (mesmo outra nota) reinicia o tempo. |
| Par separado | 2× Sol (azul), separados por um pilar | **Uma só onda** tem de tocar nas duas. Há um sítio (abaixo do pilar) de onde isso é possível. |
| Trio Dó maior | Dó, Mi, Sol (topo direito) | Cada uma tem de ouvir a sua nota em **6 s**. Possível com notas simples (trocar rápido), a partir do círculo de musgo no meio. Com o acorde Dó maior, um só ping resolve. |
| Escondida | Lá (anil), sala escura em baixo à direita | Invisível até ser tocada por um ping; a entrada não tem linha direta (pilar). Ouve-se a chamar. |

Sistemas novos:
- **Nota → cor do arco-íris** (Dó vermelho … Si violeta). O 8.º tom (Dó agudo) conta como Dó.
- **Acordes**: tríades diatónicas (Dó maior = Dó·Mi·Sol). Desbloqueio de *protótipo*: resolver 2 encontros desbloqueia Dó maior. **Q** alterna. Nenhum encontro exige acordes (testado).
- **Ping como exploração**: a camada das ondas fica por cima do nevoeiro (a onda desenha o contorno das paredes) e cada blob tocada deixa uma silhueta momentânea.
- **Blobs chamam**: as que precisam de ajuda soltam periodicamente um som posicional (2D) — dá para as encontrar de ouvido.
- **Recrutar / Absorver** (*protótipo*, depois de ajudar): Z recruta (segue-te e repete os teus pings a partir de onde está → o som pode contornar paredes); X absorve (ficas um pouco maior, vês mais longe, ganhas um leve tom da cor dela — não fica mais escuro). Sem karma, sem "bom/mau" na UI. Também se pode não decidir.
- **Mundo recupera cor**: flora e chão passam de cinzento a cor à medida que se ajudam blobs.
- **Acessibilidade**: nome da nota escrito por baixo da blob depois de ela responder (N = mostrar sempre); barra de notas com cor + nome + tecla; resposta sonora **e** visual para cada evento.

### Ficheiros
Novos: `scripts/echo/` (`echo_notes.gd`, `echo_blob.gd`, `echo_blob_group.gd`, `echo_world.gd`, `echo_hud.gd`, `echo_marker.gd`, `wall_block.gd`, `flora_patch.gd`), `scenes/echo_blob.tscn`, `scenes/world/clearing_slice.tscn`, `tests/clearing_slice_test.gd`, `tests/capture_tour.gd`.

Alterados (pequeno e retrocompatível):
- `scripts/ping_emitter.gd` — `chord_tone_indices`/`chord_colors` (vazio por omissão = comportamento antigo), som de acorde, e as ondas vão para um nó do grupo `ping_wave_layer` se existir (senão, raiz da cena como antes).
- `scripts/ping_wave.gd` — a onda guarda as notas que leva (`carries_pitch_class`), desenha anéis extra para acordes, e chama `receive_ping_wave(wave)` em recetores que o tenham (os antigos continuam a receber `receive_ping_details`).

`EchoBlob` herda de `PingDummy` (reaproveita corpo, fade de FOV e emissor). A arena de 6 zonas e `main.tscn` **não foram tocadas** e continuam a ser a cena principal / testes de regressão.

### Testes feitos (reais, no Godot 4.6.2)
- `tests/clearing_slice_test.gd` (headless, ondas e paredes reais): **22/22 ok** — nota errada responde e não liberta; tímida acorda/reinicia/liberta; par só com uma onda comum; **trio com notas simples em 6 s sem acorde**; escondida bloqueada da porta e libertada lá dentro; recrutar/absorver; companheira repete o ping; trio com acorde; janela expira sem softlock.
  ```
  Godot_v4.6.2-stable_win64_console.exe --headless --path ECHO --script res://tests/clearing_slice_test.gd
  ```
- Arena (`interaction_test_arena.tscn`) e `main.tscn` arrancam sem erros depois das alterações.
- Capturas de ecrã com `tests/capture_tour.gd` (com janela) para verificar o aspeto visual.
- **Não testado por uma pessoa a jogar**: sensação, dificuldade, volume dos sons, legibilidade. Isso é o próximo passo.

### Decisões em aberto (usei defaults reversíveis)
1. Mapeamento nota→cor final (está ROYGBIV a partir de Dó).
2. Como se ganham acordes (está "2 encontros → Dó maior"; ideia alternativa: o próprio trio ensina o acorde).
3. Tríades diatónicas (Ré menor, Si diminuto…) ou sempre maiores?
4. Recrutar/absorver: efeitos reais, custo, se é reversível, ligação a karma/final.
5. A tímida deve também ter medo de pings fortes (como a "frightened" da arena)?
6. Duração do silêncio (5 s) e da janela do trio (6 s) — afinar em playtest.
7. Papel de C/M/Y/K e da K como anciã / final.
