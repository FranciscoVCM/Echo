# Plano de desenvolvimento incremental do Echo

## 0. Baseline e isolamento
- Abrir projeto em Godot 4.6.2 e testar as seis zonas sem alterar regras.
- Verificar Output/Debugger e guardar screenshots ou vídeo do comportamento atual.
- Inicializar Git local, primeiro commit baseline, branch de desenvolvimento ou backup antes de qualquer refactor.
- Não fazer push ao repositório do colega nem editar a cópia original.

## 1. Vertical slice: o Echo realmente pretende ser
Objetivo: uma pequena zona integradora, **sem menu de minijogos**, que contenha:
- movimento e Ping com as notas existentes, já desbloqueadas;
- espaço com paredes e visibilidade reduzida; teste do Ping como instrumento de descoberta;
- duas ou três blobs com comportamentos comunicativos distintos (por exemplo tímida, escondida e ligação dupla);
- feedback sonoro e visual compreensível, acessível por cor e outro sinal;
- estado persistente de libertação dentro da zona;
- encontro pós-ajuda com escolha provisória recrutar/absorver, sem moralização automática.
Critério: o jogador compreende e ajuda criaturas usando Ping, não resolve um puzzle externo.

## 2. Refactor seguro, só depois do vertical slice
- Separar lógica comum de Ping, notas e identidade das blobs, sem reescrever tudo.
- Extrair comportamentos para componentes/regras se os testes justificarem.
- Garantir que as seis zonas antigas continuam a funcionar como regressão.

## 3. Notas e acordes
- As notas individuais já existem desde o início.
- Introduzir estruturas de acorde opcionais que combinam notas (ex. Dó maior C-E-G).
- Garantir que encontros podem ser resolvidos apenas com notas individuais.
- Definir forma de visualizar conteúdo de acordes, efeitos de alcance e colisão, e evitar confusão áudio.

## 4. Exploração e evolução do mundo
- Estender a zona a um pequeno mapa de exploração; persistir estado das criaturas entre visitas.
- Integração do sistema de visibilidade/fog of war com o Ping e pistas sonoras.
- Recrutar/absorver: medir escolhas e efeitos físicos/técnicos; validar nuance do tema de empatia.

## 5. PCG, só depois do núcleo estável
- Reutilizar padrões de interação num gerador de encontros limitado e controlado.
- Validar alcance da onda, geometria, temporização e notas disponíveis; nunca gerar softlocks.
- Playtesting para identificar padrões repetitivos ou pessoalidades inconsistentes.

## 6. Narrativa e conteúdo de longa duração
- Conteúdo especial C/M/Y/K, reintrodução gradual de cor e camadas de som.
- Final/karma só após validar com o grupo.
- Save/load, opções de acessibilidade, polishing, testes automatizados e performance.

## Forma de trabalhar com Claude Code
1. Identificar ficheiros que serão alterados antes de os alterar.
2. Fazer uma mudança pequena de cada vez.
3. Mostrar o diff e justificar alterações.
4. Abrir o Godot e executar o teste relevante (se o ambiente permitir); não declarar que testou sem testar.
5. Manter log `DEVLOG.md` com decisão, motivo e verificações.
6. Parar e perguntar antes de remover funcionalidade do colega ou fechar decisões de narrativa não acordadas.
