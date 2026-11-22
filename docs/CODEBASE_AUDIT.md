# Auditoria estática do Godot fornecido (não é relatório de runtime)

Fonte: `echo.zip`, projeto em `echo/ECHO/`. Versão declarada no README: Godot **4.6.2**. Configuração em `project.godot`: `config/features=["4.6", "GL Compatibility"]`, renderer Compatibility e cena principal `res://scenes/interaction_test_arena.tscn`.

## Conteúdo existente, confirmado por leitura de código
- **Seis zonas de teste**, HUD, teleporte F1-F6 e reset R/Shift+R: `scripts/interaction_test_arena.gd`.
- **Interações** FRIGHTENED, CONNECTION, LOST, FREQUENCY, RESONANCE e SILENCE: `scripts/small_blob_interaction.gd`. Coordination de conexões e ressonância: `scripts/blob_interaction_coordinator.gd`.
- **Movimento/top-down e dash:** `scripts/player_controller.gd`, `scripts/top_down_movement.gd`; `resources/default_top_down_movement.tres`.
- **Ping por E (hold/release), carga, cooldown, ondas e tons:** `scripts/ping_emitter.gd`, `scripts/ping_wave.gd`. Os tons implementados são C3 D3 E3 F3 G3 A3 B3 C4, com pré-visualização sonora sintetizada.
- **Ping bloqueado por obstáculos:** `ping_wave.gd`, ray sampling e máscara de colisão. Verificar desempenho e acerto em runtime.
- **Visual blob orgânico:** `scripts/blob_visual.gd`.
- **Campo de visão / shader:** `scripts/field_of_view.gd`, `resources/field_of_view.gdshader`; teste antigo `scenes/main.tscn` e a arena.
- **Outro teste:** `scenes/main.tscn` conserva uma sala com PingDummy para investigar Ping e campo de visão.
- **Add-on:** `addons/visibility_polygon`, incluído com LICENSE original.

## Controlos descritos no README do projeto
- WASD/setas: mover; E pressionar/soltar: carregar e emitir Ping.
- Roda do rato ou 1-8: selecionar nota (C3 até C4).
- Espaço: dash (experimental); F1-F6: zonas de teste.
- R: reset de zona; Shift+R: reset total.

## O que ainda NÃO foi confirmado em código
- Mundo aberto contínuo, mapa narrativo e progressão principal.
- Recrutar/absorver com estado persistente de equipa/massa/karma.
- Acordes desbloqueáveis e emissão multi-nota.
- PCG de encontros validado, salvaguarda de softlocks, conteúdos dos encontros C/M/Y/K.
- Narrativa e finais completos, recuperação global de cor, save/load.
- Testes automatizados e benchmark de frame-rate.

## Cuidados técnicos
- **Não existe pasta `.git/` no ZIP recebido.** Não assumir branch/repo/remoto disponível.
- Os scripts/cenas foram copiados sem modificação. A pasta `.godot/` de cache foi omitida; o Godot recria.
- Não usar o ficheiro Windows `Godot_v4.6.2-stable_win64.exe` do ZIP como ficheiro de projeto. Instalar/abrir o Godot na máquina local.
- O projeto ainda não foi aberto nem executado neste ambiente. A verificação é estática. Começar por import e smoke test em Godot 4.6.2.
- Os ficheiros de PowerPoint/revisões de apresentação e o executável Windows do ZIP original foram omitidos por não serem dependências do jogo.

## Ficheiros a ler primeiro
`project.godot`, `README.md`, `scenes/interaction_test_arena.tscn`, `scripts/interaction_test_arena.gd`, `scripts/player_controller.gd`, `scripts/ping_emitter.gd`, `scripts/ping_wave.gd`, `scripts/small_blob_interaction.gd`, `scripts/blob_interaction_coordinator.gd`, `scripts/field_of_view.gd`.
