# ECHO: design atual e decisões confirmadas

Data de referência: 22-11-2026. Este ficheiro sintetiza as decisões mais recentes fornecidas por um dos membros do grupo. **Distinguir o design pretendido do código já implementado**.

## Identidade e tema
- **Echo**: jogo 2D top-down protagonizado por uma blob num mundo estranho, pouco colorido e inicialmente desconhecido. Mundo orgânico, fluido, com forte identidade de som e cor.
- Tema principal: **empatia**. Aprender a interpretar o comportamento de outras blobs, adaptar a nossa forma de comunicar e só então construir relações.
- Dimensões centrais: sensemaking, sensoriality e playfulness. O professor sugeriu abandonar o predomínio de minijogos, porque desviavam a experiência para o challenge.
- Evitar reduzir a empatia a um sinal numérico que diga ao jogador o que é moralmente correto.

## O Ping é a mecânica central
- Disponível **desde o início do jogo**; todas as sete notas da escala estão disponíveis inicialmente: Dó, Ré, Mi, Fá, Sol, Lá e Si. O protótipo usa também um Dó na oitava seguinte (8 opções C3...C4).
- A nota do Ping corresponde à cor/identidade sonora da blob. O mapeamento exato entre as sete notas e as sete cores **ainda deve ser confirmado pelo grupo**; um exemplo discutido foi vermelho -> Dó. Não assumir que a cor atual do protótipo já é a mapeação final.
- Um Ping é uma onda propagada no espaço, sujeita à geometria/obstáculos, que pode revelar criaturas, obter respostas, ajudar ou incomodar conforme o contexto.
- O jogador pode carregar o Ping para controlar alcance/intensidade, mas isto exige tuning para ser legível e respeitar necessidades das blobs.
- Com a progressão, o Ping individual pode ser melhorado para **acordes** (por exemplo Dó maior = Dó + Mi + Sol). Isso facilita interações múltiplas ou simultâneas. **Os acordes nunca são condição obrigatória de acesso**; cada encontro deve poder ser resolvido com notas individuais para preservar o open world. Não bloquear regiões por upgrades.
- O conceito de *fog of war* / visibilidade reduzida pode apoiar a exploração, desde que seja divertido e que o Ping tenha valor real além de revelar um ícone automaticamente.

## Tipos de interação, atualmente exemplificados em código
1. Frightened blob: prefere três sinais curtos e delicados; um Ping forte a assusta e pode reiniciar o progresso.
2. Sound connection: colocar-se de modo que a **mesma onda** alcance duas blobs, por exemplo contornando um obstáculo.
3. Echolocation: blob oculta tem de ser revelada por um Ping antes da interação de ajuda.
4. Frequency matching: compreender e responder à nota adequada (no laboratório, G3).
5. Group resonance: várias blobs devem ser alcançadas dentro de uma janela de tempo. Um acorde apropriado pode tornar uma situação assim mais fácil, nunca a única solução.
6. Silence: emitir um Ping e depois respeitar um período de silêncio, pois novos Pings podem perturbar a blob.

Estes seis exemplos já existem como PROTÓTIPOS, não são toda a experiência final e podem precisar de alteração. Não se pretende que pareçam seis minijogos isolados; integrar gradualmente as suas regras no mundo e nas personalidades das personagens.

## Mundo, narrativa e evolução
- Exploração **open world** ou com deslocação livre e progressão não rigidamente linear. Evitar uma sequência de salas de minijogos.
- O mundo recupera gradualmente cor/som à medida que o jogador constrói relações e interage com as criaturas.
- Blobs C, M e Y: encontros maiores, com identidade temática associada a cor/som. K: anciã ou personagem do confronto final, mas a função exata e o ending continuam por confirmar.
- Em notas antigas, K causou a perda de cor e o final depende de karma. Esta narrativa é uma **direção em discussão, não um contrato fechado**. Não a implementar integralmente sem acordo com o grupo.

## Recrutar ou absorver: mecânica ainda por aperfeiçoar
- Depois de compreender e ajudar uma blob, pode haver decisão de recrutá-la como companhia ou absorvê-la na protagonista.
- Recrutar pode dar vantagens de equipa, ações técnicas, ajuda contextual e novas formas de cooperação; absorver pode aumentar massa, visão e força/alcance físicos.
- Não tratar necessariamente a absorção como "mau" sem nuance. O protótipo antigo tornava o avatar mais escuro; os jogadores interpretaram imediatamente como uma decisão má, o que prejudica a ambiguidade moral.
- Não transformar uma blob apenas num item de upgrade. Ajudar tem de fazer sentido na personalidade e no comportamento da criatura.
- A implementação concreta, recompensas, custo, sentido de karma e impacto no final **precisam de validação com o grupo** antes de serem considerados fixos.

## PCG: proposta do A7, não funcionalidade já implementada
- Geração de **encontros/contextos** usando padrões de interação, posições, obstáculos, distância, tempos e notas; não geração aleatória de minijogos desconectados.
- Designer cria padrões e restrições; computador gera e verifica validade; jogador influencia seleção indiretamente e avalia em testes.
- Garantir resolubilidade sem acordes, coerência de personalidade e situações legíveis.
- C/M/Y/K devem permanecer maioritariamente encontros desenhados manualmente.
- **Adiamento recomendado:** implementar PCG apenas depois de existir um loop de Ping + blobs integrado e testado manualmente.

## O que foi abandonado / não assumir
- Os minijogos separados de memória, reflexos, cartas, copos, etc. **foram retirados do plano atual**.
- O desbloqueio tardio do próprio Ping foi abandonado: o Ping está disponível desde o início.
- O antigo modelo A6 que exigia 3 minijogos por área e boss em seguida já não é a regra canónica.
- Não usar conceitos de Plague Inc. do A2 como base atual do Echo.

## Decisões abertas
- Correspondência exata nota-cor e extensão de oitavas; representação acessível para pessoas com daltonismo / sem som.
- Quais os acordes, quando evoluem e como se obtêm.
- Se/como recrutamento, absorção e karma influenciam o comportamento da equipa.
- Estrutura final do mundo e mapa, relevância de K, narrativa final e bosses.
- Dimensão, dificuldade, ritmo, interface, arte e critérios de playtest.

Não inventar decisões fechadas. Para protótipos reversíveis, usar defaults temporários e assinalá-los.
