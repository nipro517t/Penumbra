# Penumbra

Platformer 2D de ação (parkour + combate rápido) feito em **Godot 4.7 com GDScript**.
Tema: **Luz e Sombra**. Projeto de Game Jam (protótipo em andamento).

## A ideia
Um herói ágil atravessa um mundo consumido pela escuridão. A luz é refúgio e recurso:
- **Brasa:** barra de energia gasta em dash, corrida, deslize com brasa e cura; recarrega nas fontes de luz.
- **Sanidade:** cai fora da luz; criaturas de olhos vermelhos surgem nas bordas da tela e, ao zerar, "pegam" o herói e ele volta ao último checkpoint.
- **Voz em vermelho:** texto que fala com o jogador em pontos específicos.
- **Twist (em estudo):** a escuridão é uma reação ao que a humanidade fez ao mundo; a crítica final é que *foi ela mesma* que se destruiu.

## Como rodar
1. Abra o projeto no Godot **4.7** (`project.godot`).
2. Aperte **F5**. A cena principal é `scenes/main.tscn`.
3. Se aparecer erro de tipo (`Player` ou `EmberComponent` não encontrado) na primeira abertura, feche e reabra o projeto.

## Controles
| Ação | Teclado | PS4 |
|---|---|---|
| Mover | A/D ou ←/→ | Analógico esq. ou D-pad |
| Pular | Espaço | ✕ |
| Dash (instantâneo, gasta brasa; no ar vai na direção apertada) | K | ○ ou R1 |
| Correr (segurar; grátis por padrão) | Shift | R2 |
| Curar (segurar) | Q | △ |
| Slide | C ou Ctrl | L1 ou L2 |
| Cima (mira do dash no ar) | W ou ↑ | Analógico/D-pad para cima |
| Agachar | S ou ↓ | Analógico/D-pad para baixo |
| Atacar (ainda sem efeito) | J ou clique | □ |
| Interagir (ainda sem efeito) | E | R3 |

## Estrutura
```
scenes/
  main.tscn          cena principal (Level + Player + barra de brasa)
  player.tscn        herói (CharacterBody2D, sprite, câmera, luz, Ember)
  test_level.tscn    fase de teste (túnel baixo, poço, poço com paredes, luzes)
  light_source.tscn  fonte de luz (recarrega a brasa)
  ember_bar.tscn     barras de teste na tela (brasa e sanidade)
  shadow_eyes.tscn   criaturas de olhos vermelhos nas bordas + vinheta + "pegada"
  voice_box.tscn     caixa de voz em vermelho
scripts/
  player.gd          movimento e estados
  ember_component.gd barra de brasa
  light_source.gd    recarga de brasa nas luzes
  kill_zone.gd       queda no vazio: volta ao início
  ember_bar.gd       atualiza as barras na tela
  sanity_component.gd sanidade (cai fora da luz, estágios, sinal broke)
  game_state.gd      Autoload: checkpoint, flags, finais e save em disco
  shadow_eyes.gd     criaturas nas bordas e sequência de "pegada" + respawn
  voice_box.gd       falas em vermelho digitadas, uma por vez
  voice_trigger.gd   área que dispara falas (edite "lines" no Inspetor)
assets/player/adventurer/   frames do herói (arte provisória)
```

## Como funciona (resumo)
- **Player** (`player.gd`): máquina de estados `IDLE, RUN, JUMP, FALL, WALL_SLIDE, CROUCH, SLIDE, DASH`. Tudo se ajusta no **Inspetor** do nó `Player` (grupos Movimento, Pulo, Parede, Agachar e Deslizar, Dash, Visual, Luz), sem mexer no código.
- **Dash:** instantâneo, gasta brasa (`dash_ember_cost`), tem i-frames, cooldown e rastro. **No chão** é um deslize horizontal com colisão baixa. **No ar** vai em 8 direções (`dash_air_8_directions`); para cima é mais curto (`dash_up_multiplier`). Sem direção apertada, segue para onde o herói olha. Pular durante o dash no chão cancela o dash e mantém o impulso.
- **Slide curto:** botão próprio (`slide`), sem brasa. **Deslize com brasa:** apertar slide *enquanto corre* gasta brasa por segundo (`power_slide_ember_per_second`) e dura até `power_slide_max_duration` (0 = até a brasa acabar), desde que a corrida continue segurada; depois desacelera como um slide normal.
- **Corrida:** segurar `sprint` move mais rápido (`sprint_speed`). **Grátis por padrão** (`sprint_ember_per_second = 0`); coloque um valor para cobrar brasa por segundo. A sanidade cai mais devagar enquanto corre. Pular correndo mantém a velocidade no ar (mais alcance) e dá um bônus pequeno de altura.
- **Cura:** segurar `heal` ~1 s no chão converte brasa em sanidade (`heal_ember_cost`, `heal_sanity_amount`); o herói anda mais devagar enquanto cura.
- **Brasa:** `EmberComponent` (`spend`, `drain`, `refill`, sinal `changed`). Não drena sozinha; só queima no estado crítico da sanidade.
- **Quinas:** no ar, segurando em direção a uma parede cujo topo está na altura da cabeça, o herói se pendura (`LEDGE_HANG`). **Pular** sobe (`LEDGE_CLIMB`); **agachar** ou segurar para longe solta. Ajustes no grupo *Quina* do Inspetor.
- **Sanidade:** `SanityComponent` no `Player`. Cai fora das fontes de luz e recupera dentro (`drain_per_second`, `recover_per_second`). Ao chegar no **marcador crítico** (`critical_ratio`) ela para e a **brasa queima** (`critical_ember_per_second`); sem brasa, volta a cair até quebrar. Criaturas aparecem nas bordas por estágios; ao zerar, elas "pulam" e o herói volta ao último checkpoint. A barra de sanidade pulsa em vermelho no estado crítico.
- **Checkpoint:** cada `LightSource` é checkpoint ao ser tocada. A zona de queda também usa o checkpoint.
- **Voz em vermelho:** `VoiceTrigger` (Area2D) dispara as falas escritas no Inspetor; `GameState.say("...")` fala por código. As falas atuais são só marcadores.
- **Luz:** `CanvasModulate` escurece a fase; `PointLight2D` no herói (tamanho segue a brasa) e nas fontes de luz.
- **Luz do herói:** o tamanho e a força da luz seguem a **sanidade** (não a brasa); a vinheta na tela é sutil e avermelhada.
- **Pés alinhados:** `anim_y_offset` ajusta a altura do sprite por animação (queda +4, wall slide +2).
- **Arte do herói e tileset são provisórios** e serão substituídos por arte própria.

## Status

### Feito
- [x] Projeto Godot 4.7, viewport 480×270 (janela 1440×810), filtro Nearest
- [x] Input Map com teclado e controle de PS4
- [x] Movimento: corrida, pulo variável, coyote time e jump buffer
- [x] Parede: wall slide e wall jump
- [x] Agachar e slide por botão
- [x] Dash com brasa, rastro, deslize no chão e cancelamento por pulo
- [x] Animações do herói montadas (idle, run, jump, fall, wall slide, crouch, slide, dash)
- [x] Brasa + barra na tela + fonte de luz que recarrega
- [x] Fase de teste com túnel, poço de dash, poço com paredes e zona de queda
- [x] GDD e este README
- [x] Agarrar e escalar quinas (a testar)
- [x] Sanidade, criaturas nas bordas, checkpoint e respawn (a testar)
- [x] Caixa de voz em vermelho e gatilhos de fala (a testar)
- [x] Corrida e deslize com brasa, cura, estado crítico e luz que segue a sanidade (a testar)
- [x] `GameState` (Autoload) com flags, finais e save em disco

### A fazer (ordem sugerida)
- [ ] Testar e ajustar o "feeling" do movimento, do dash, das quinas e da sanidade (valores no Inspetor)
- [ ] Testar o uso das brasas (dash em 8 direções, deslize com brasa, cura, estado crítico) e a corrida grátis; ajustar os custos
- [ ] Escrever as falas da voz (hoje são marcadores) e ligar falas aos estágios de sanidade
- [ ] Combate: combo de 3 golpes, ataque aéreo, hitbox/hurtbox
- [ ] Inimigos (tipos a definir)
- [ ] Nível do Capítulo 1 (3 a 4 trechos) com tileset
- [ ] Corredor escuro (cena especial)
- [ ] Eco (NPC) com diálogo
- [ ] Cutscene de abertura (cidade que decai) e tela de título
- [ ] Polimento: câmera, partículas, hitstop, áudio, UI
- [ ] Imunidade à sombra após o final (flag no `GameState`)

### Decisões em aberto
- [ ] Protagonista (humano ou robô movido a luz?) e design final
- [ ] Ambientação e estética (Solar Punk que fracassou?)
- [ ] Twist exato e como plantar as pistas
- [ ] Mecânica extra de luz (inimigos vulneráveis à luz ou sombras como plataformas)
- [ ] Resolução e paleta definitivas da pixel art
- [ ] Como a sanidade interage com o dano de inimigos

## Uso de IA no projeto
- **Código e lógica:** parte dos scripts e da estrutura de cenas foi escrita com ajuda do assistente **Claude (Anthropic)** e revisada/ajustada pelo autor.
- **Planejamento:** o Claude também é usado para sugerir e comentar decisões de design e para ajudar a redigir a documentação (GDD e este README). As decisões finais são do autor.
- **Arte, áudio e textos do jogo:** feitos à mão pelo autor. Os sprites do personagem e o tileset atuais são arte **provisória de terceiros**, a ser substituída por arte própria.
- Se algum conteúdo gerado por IA (arte, áudio ou texto) for usado no futuro, ele será declarado aqui e nas páginas de publicação (itch.io, Steam etc.).

## Ordem de corte (se faltar tempo na Jam)
Polimento → eco/NPC → cutscene → combate. O mínimo jogável é: movimento + dash + luz + sanidade com respawn + um trecho de nível + voz em vermelho.
