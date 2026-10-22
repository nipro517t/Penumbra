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
| Slide (baixo correndo) | ↓ ou S correndo | Analógico/D-pad para baixo correndo |
| Cima (mira do dash no ar) | W ou ↑ | Analógico/D-pad para cima |
| Agachar | S ou ↓ | Analógico/D-pad para baixo |
| Atacar (combo de 3 golpes no chão, golpe no ar) | J ou clique esquerdo | □ |
| Interagir (ainda sem efeito) | E | R3 |

## Estrutura
```
scenes/
  main.tscn          cena principal (Level + Player + barra de brasa)
  player.tscn        herói (CharacterBody2D, sprite, câmera, luz, Ember)
  test_level.tscn    fase de teste (túnel baixo, poço, poço com paredes, luzes)
  light_source.tscn  fonte de luz (recarrega a brasa)
  enemy_shadow.tscn  inimigo rastejador de sombra
  main_menu.tscn     menu principal estilizado (raio de luz)
  echo.tscn          eco (NPC): fala com o herói
  dialog_box.tscn    caixa de diálogo (texto digitado)
  ember_bar.tscn     barras de teste na tela (brasa e sanidade)
  shadow_eyes.tscn   criaturas de olhos vermelhos nas bordas + vinheta + "pegada"
  voice_box.tscn     caixa de voz em vermelho
scripts/
  player.gd          movimento e estados
  ember_component.gd barra de brasa
  light_source.gd    recarga de brasa nas luzes
  kill_zone.gd       queda no vazio: volta ao início
  enemy_shadow.gd    inimigo: patrulha, persegue, leva dano e morre
  main_menu.gd       menu: constrói o cenário, o raio de luz e os botões por código
  echo.gd            eco: detecta o herói, abre a conversa, avisos e falas ao sair
  dialog_box.gd      caixa de diálogo: `await box.open(nome, [linhas])`
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
- **Slide:** apertar **baixo** correndo (acima de `slide_down_min_speed`). Não há botão dedicado. No analógico o baixo precisa estar quase pleno (`slide_down_stick_threshold`) e só conta ao *apertar*. A velocidade inicial é a velocidade anterior × `slide_speed_multiplier`, então quanto mais rápido, mais longe desliza. A colisão fica bem baixa (`slide_height`) para passar por vãos baixos. Se a corrida continuar segurada, ao fim do deslize o herói volta a correr; senão, para (ou agacha, se baixo ainda estiver segurado).
- **Corrida:** segurar `sprint` move mais rápido (`sprint_speed`). **Grátis por padrão** (`sprint_ember_per_second = 0`); coloque um valor para cobrar brasa por segundo. A sanidade cai mais devagar enquanto corre ou desliza segurando a corrida. Pular correndo mantém a velocidade no ar (mais alcance) e dá um bônus pequeno de altura.
- **Cura:** segurar `heal` ~1 s no chão converte brasa em sanidade (`heal_ember_cost`, `heal_sanity_amount`); o herói anda mais devagar enquanto cura.
- **Brasa:** `EmberComponent` (`spend`, `drain`, `refill`, sinal `changed`). Não drena sozinha; só queima no estado crítico da sanidade.
- **Quinas:** no ar, segurando em direção a uma parede cujo topo está na altura da cabeça, o herói se pendura (`LEDGE_HANG`). **Pular** sobe (`LEDGE_CLIMB`); **agachar** ou segurar para longe solta. Ajustes no grupo *Quina* do Inspetor.
- **Sanidade:** `SanityComponent` no `Player`. Cai fora das fontes de luz e recupera dentro (`drain_per_second`, `recover_per_second`). Ao chegar no **marcador crítico** (`critical_ratio`) ela para e a **brasa queima** (`critical_ember_per_second`); sem brasa, volta a cair até quebrar. Criaturas aparecem nas bordas por estágios; ao zerar, elas "pulam" e o herói volta ao último checkpoint. A barra de sanidade pulsa em vermelho no estado crítico.
- **Checkpoint:** cada `LightSource` é checkpoint quando ilumina o herói (precisa de linha de visão).
- **Voz em vermelho:** `VoiceTrigger` (Area2D) dispara as falas escritas no Inspetor; `GameState.say("...")` fala por código. As falas atuais são só marcadores.
- **Luz:** `CanvasModulate` escurece a fase; `PointLight2D` no herói (tamanho segue a brasa) e nas fontes de luz.
- **Zona de luz com linha de visão:** a `LightSource` só conta o herói como "na luz" se ele estiver dentro da zona (`zone_ratio` × o raio do brilho) **e** nenhum chão, parede ou teto estiver entre a lâmpada e ele (raios para cabeça, centro e pés). Os blocos da fase de teste têm `LightOccluder2D` (levemente recuados, para a borda continuar iluminada) e as luzes projetam sombras. Em TileMaps, use a camada de oclusão do TileSet.
- **Combate:** apertar atacar no chão faz um combo de 3 golpes (`combo_damage`, o último é o finalizador); apertar de novo dentro de `combo_window` continua o combo. No ar, um golpe aéreo. O dash cancela o golpe (e dá i-frames). Cada golpe só machuca na parte "ativa" da animação (`hit_windows`) e uma vez por inimigo. Acertar recarrega brasa (`ember_per_hit`, mais ao matar), dá uma pausa curta no impacto (`hitstop_time`) e treme a câmera.
- **Invulnerabilidade:** o dash dá i-frames durante o impulso e mais `dash_iframe_grace` (0,25 s) depois, para dar tempo de sair de dentro de um inimigo atravessado. Enquanto invulnerável (dash) o herói fica azulado e translúcido; ao levar dano ele pisca.
- **Dano no herói:** o inimigo ao encostar tira **sanidade** (`contact_damage`), empurra o herói (`hurt_knockback`), atordoa por um instante e dá invulnerabilidade curta (o herói pisca). O dash também desvia.
- **Inimigo (`enemy_shadow`):** patrulha perto do ponto inicial, vira em paredes e bordas, persegue o herói quando o enxerga (`sight_range`), depois de ferir o herói recua (`recoil_time`) e espera `attack_cooldown` antes de poder ferir de novo, leva knockback ao ser atingido e morre depois de `max_health` de dano. É só uma silhueta com olhos brilhantes, desenhada por código (sem arte).
- **Camadas de colisão:** 1 = mundo e herói; 2 = corpo dos inimigos (não bloqueia o herói); 3 = hurtbox dos inimigos (a área do golpe do herói só enxerga esta).
- **Menu principal (`main_menu.tscn`):** um raio de luz (uma `PointLight2D` em cone + um feixe visível aditivo) sai de cima e **mira o botão selecionado**; uma segunda luz "de revelação" ilumina uma parte diferente do cenário por opção (Jogar: o herói; Configurações: engrenagens; Créditos: ecos). Em **Sair** a luz e o raio se apagam e surgem olhos vermelhos. O herói aparece de lado olhando para a luz (a arte atual não tem vista de costas). Tudo é construído por código e ajustável no Inspetor do nó `MainMenu` (cores, tamanhos de fonte, posição do raio...). Para testar o menu: abra a cena e aperte **F6**. Para o jogo abrir pelo menu, defina `main_menu.tscn` como cena principal (*Projeto → Configurações → Aplicação → Executar*). "Jogar" vai para `main.tscn`; "Configurações" e "Créditos" ainda mostram "Em breve."
- **Eco (NPC) e diálogo:** o eco é um vulto translúcido e levemente luminoso. Com `auto_start` ligado, a **primeira** conversa começa sozinha quando o herói chega perto (no chão); as seguintes pedem apertar **interact** (aparece o aviso "[E] Falar"). Durante a conversa o herói fica parado e a sanidade pausa. As **falas são suas**: edite `lines` (conversa), `repeat_lines` (se falar de novo; vazio = não conversa mais) e `leave_lines` (comentário solto ao se afastar) no Inspetor; os textos atuais são marcadores. A caixa de diálogo digita o texto; **interact / Enter / Espaço / ✕** avançam (o primeiro aperto completa a linha). `flag_to_set` marca um flag no `GameState`. A `DialogBox` é criada sozinha na cena atual se ainda não existir.
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
- [x] Eco (NPC) com caixa de diálogo de texto digitado (a testar; falas a escrever)
- [x] Menu principal estilizado: raio de luz que mira o botão, revelação por opção e "Sair" apaga tudo (a testar)
- [x] Combate: combo de 3 golpes, golpe aéreo, hitbox/hurtbox, dano na sanidade e 1 inimigo (a testar)
- [x] Corrida grátis, deslize por velocidade (baixo correndo), cura, estado crítico e luz que segue a sanidade (a testar)
- [x] `GameState` (Autoload) com flags, finais e save em disco

### A fazer (ordem sugerida)
- [ ] Testar e ajustar o "feeling" do movimento, do dash, das quinas e da sanidade (valores no Inspetor)
- [ ] Testar o uso das brasas (dash em 8 direções, cura, estado crítico) e a corrida grátis; ajustar os custos
- [ ] Escrever as falas da voz (hoje são marcadores) e ligar falas aos estágios de sanidade
- [ ] Mais tipos de inimigo (ex.: voador à distância) e comportamento em relação à luz
- [ ] Nível do Capítulo 1 (3 a 4 trechos) com tileset
- [ ] Corredor escuro (cena especial)
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
