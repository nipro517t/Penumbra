# Penumbra

Platformer 2D de ação (parkour + combate rápido) feito em **Godot 4.7 com GDScript**.
Tema: **Luz e Sombra**. Projeto de Game Jam (protótipo em andamento).

## A ideia
Um herói ágil atravessa um mundo consumido pela escuridão. A luz é refúgio e recurso:
- **Brasa:** barra de energia que alimenta o dash; recarrega nas fontes de luz.
- **Sanidade (planejado):** cai fora da luz; criaturas de olhos vermelhos surgem nas bordas da tela e, ao zerar, "pegam" o herói e ele volta ao último checkpoint.
- **Voz em vermelho (planejado):** texto que fala com o jogador em pontos específicos.
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
| Dash | Shift | ○, R1 ou R2 |
| Slide | C ou Ctrl | L1 ou L2 |
| Agachar | S ou ↓ | Analógico/D-pad para baixo |
| Atacar (ainda sem efeito) | J ou clique | □ |
| Interagir (ainda sem efeito) | E | △ |

## Estrutura
```
scenes/
  main.tscn          cena principal (Level + Player + barra de brasa)
  player.tscn        herói (CharacterBody2D, sprite, câmera, luz, Ember)
  test_level.tscn    fase de teste (túnel baixo, poço, poço com paredes, luzes)
  light_source.tscn  fonte de luz (recarrega a brasa)
  ember_bar.tscn     barra de brasa na tela
scripts/
  player.gd          movimento e estados
  ember_component.gd barra de brasa
  light_source.gd    recarga de brasa nas luzes
  kill_zone.gd       queda no vazio: volta ao início
  ember_bar.gd       atualiza a barra na tela
assets/player/adventurer/   frames do herói (arte provisória)
```

## Como funciona (resumo)
- **Player** (`player.gd`): máquina de estados `IDLE, RUN, JUMP, FALL, WALL_SLIDE, CROUCH, SLIDE, DASH`. Tudo se ajusta no **Inspetor** do nó `Player` (grupos Movimento, Pulo, Parede, Agachar e Deslizar, Dash, Visual, Luz), sem mexer no código.
- **Dash:** gasta brasa (`dash_ember_cost`), tem cooldown e rastro. No chão vira um deslize com colisão baixa (`dash_slides_on_ground`). Pular durante o dash cancela o dash e mantém o impulso.
- **Slide:** botão próprio (ação `slide`, criada por código se não existir no Mapa de Entrada). Seta para baixo só agacha.
- **Brasa:** `EmberComponent` (`spend`, `refill`, sinal `changed`). Não drena sozinha (`draining` desligado); a pressão virá da sanidade.
- **Luz:** `CanvasModulate` escurece a fase; `PointLight2D` no herói (tamanho segue a brasa) e nas fontes de luz.
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
- [x] GDD (rascunho v6) e este README

### A fazer (ordem sugerida)
- [ ] Testar e ajustar o "feeling" do movimento e do dash (valores no Inspetor)
- [ ] Agarrar e escalar quinas (animações `crnr-grb` e `crnr-clmb` já existem)
- [ ] **Sanidade:** `sanity_component.gd`, drenagem fora da luz, recuperação na luz
- [ ] **Criaturas nas bordas** (`ShadowEyes`, CanvasLayer) e "pulo" ao zerar a sanidade
- [ ] **Checkpoint e respawn:** `GameState` (Autoload) com o último checkpoint (fonte de luz)
- [ ] **Voz em vermelho:** `VoiceBox` + gatilhos por área e por faixa de sanidade
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
