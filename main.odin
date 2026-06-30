package game

import "core:fmt"
import "core:math/linalg"
import "core:mem"
import "core:c"
import "core:math/rand"
import "core:time"
import "core:strings"
import "core:os"
import "core:strconv"
import rl "vendor:raylib"
import glue "gluelib"
import gluerl "gluelib/raylibtools"

// -----------------------------------------------------------------------------------------------
// CONSTANTS
// -----------------------------------------------------------------------------------------------

DRAW_HITBOXES :: false
PLAY_SOUND :: true

WINDOW_WIDTH : c.int  : 800
WINDOW_HEIGHT : c.int :  1000
WINDOW_BACKCOLOR : rl.Color : {128,128,128,255}
PLAYER_RECOVERY_COOLDOWN : f32 = 1 // in seconds
PLAYER_MAX_BULLETS : int = 5
MAX_ENEMIES : int : 20
ENEMY_VELOCITY_DEFAUL : f32 : 20
SPAWM_ENEMY_EVERY_SECONDS : f32 = 2
MAX_SCORE_FILE : string = ".\\max_score.txt"
FONT_FILE : cstring : ".\\resources\\fonts\\ByteBounce.ttf"
PATH_TEXTURES : string : ".\\resources\\sprites\\"
PATH_SOUNDS : string : ".\\resources\\sounds\\"

// -----------------------------------------------------
// SPRITES
// -----------------------------------------------------


@(rodata)
FILE_NAMES := []string{ "submarine.png", "submarine2.png", "enemy1.png", "bullet.png", "mine.png",  "background.png", "bullet_cooldown.png", "player_in_radar.png",
                        "enemy_in_radar.png", "_mine_in_radar.png","bullet_in_radar.png", "heart_red.png" , "heart_gray.png", "enemy_explosion.png", "start_screen.png" }
IMG_PLAYER := 0
IMG_PLAYER_2 := 1 // not used
IMG_ENEMY := 2
IMG_BULLET := 3
IMG_TORPEDO := 4
IMG_BACKGROUND := 5
IMG_BULLET_COOLDOWN := 6
IMG_PLAYER_IN_RADAR := 7
IMG_ENEMY_IN_RADAR := 8
IMG_MINE_IN_RADAR := 9
IMG_BULLET_IN_RADAR := 10
IMG_HEART_RED := 11
IMG_HEART_GRAY := 12
IMG_ENEMY_EXPLOSION : = 13
IMG_START_SCREEN := 14

// -----------------------------------------------------
// SOUNDS
// -----------------------------------------------------

@(rodata)
SOUND_FILES := []string{ "enemy_explosion.ogg", "player_hit.ogg", "player_fire.ogg", "game_over_bad_chest.ogg" }
SND_ENEMY_EXPLOSION := 0
SND_PLAYER_HIT := 1
SND_PLAYER_FIRE := 2
SND_GAME_OVER := 3

// -----------------------------------------------------------------------------------------------
// TYPES
// -----------------------------------------------------------------------------------------------

SpriteStruct :: struct {
	texture: rl.Texture2D,
}

GameDataStruct :: struct {
	version: string,
	sprites: [dynamic]SpriteStruct,
	camera : rl.Camera2D,
	enemies_alive: [dynamic]EnemyStruct,
	bullets_alive : [dynamic]BulletStruct,
	torpedos_alive : [dynamic]TorpedoStruc,
	explosions : [dynamic]ExplosionStruct,
    font : rl.Font,
    sounds : [dynamic]rl.Sound,
    is_running : bool,
    current_max_record : int
}

PlayerStruct :: struct {
    position : [2]f32,
    velocity : f32,
    sprite : rl.Texture2D,
    score : uint,
    lives : int,
    player_remaining_bullets : int,
    time_to_cooldown : f32
}

BulletStruct :: struct {
    position, direction : [2]f32,
    velocity : f32,
    rotation: f32,
    delete : bool
}

TorpedoStruc :: struct {
    position, direction : [2]f32,
    velocity : f32,
    delete : bool
}

EnemyStruct :: struct {
    position, direction : [2]f32,
    velocity : f32,
    lastFire : f32,
    fireEvery : f32, // sconds
    delete : bool
}

ExplosionStruct :: struct {
    position : [2]f32,
    duration : f32
}

// -----------------------------------------------------------------------------------------------
// GLOBALS
// -----------------------------------------------------------------------------------------------

game_data: GameDataStruct
player : PlayerStruct
input : rl.Vector2
time_accumulator : f32 = 0
time_since_last_spawn : f32 = 0

// -----------------------------------------------------------------------------------------------
// CODE START
// -----------------------------------------------------------------------------------------------

main :: proc() {
    // -----------------------------------------------------
    //             setup tracking allocator in debug
    // -----------------------------------------------------
    when ODIN_DEBUG {
            track: mem.Tracking_Allocator
            mem.tracking_allocator_init(&track, context.allocator)
            context.allocator = mem.tracking_allocator(&track)
            defer {
                if len(track.allocation_map) > 0 {
                    fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                    for _, entry in track.allocation_map {
                        fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                    }
                }
                if len(track.bad_free_array) > 0 {
                    fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                    for entry in track.bad_free_array {
                        fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                    }
                }
                mem.tracking_allocator_destroy(&track)
            }
        }

    // -----------------------------------------------------
    //             setup crash handler
    // -----------------------------------------------------
    glue.set_crash_handler(glue.crash_handler_type.BACKTRACE)

    // -----------------------------------------------------
    //             start..
    // -----------------------------------------------------

    // ----------
    rl.SetTraceLogLevel(rl.TraceLogLevel.ERROR)

    rl.SetTargetFPS(60)
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Warship")
    defer rl.CloseWindow()

    icono : rl.Image = rl.LoadImage(".\\resources\\sprites\\enemy_explosion.png");
    defer rl.UnloadImage(icono);
    rl.SetWindowIcon(icono)

    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    // Init game time struct ----------------
    gt : glue.GameTime
    gt.startTime = time.now()._nsec
    gt.previousTime = time.now()._nsec
    gt.fixed_update_interval = glue.FIXED_UPDATE_TIMESTEP_60HZ
    gt.lag_accumulator = 0.0
    gt.totalGameTime = 0
    // ----------------

    gluerl.console_init(WINDOW_WIDTH, WINDOW_HEIGHT, max_lines=20, color={20,20,20,255})
    defer gluerl.console_delete()
    gluerl.console_show()

    init_game_data()
    defer delete_gamedata()

    player = { {100,44} , 300 ,  game_data.sprites[IMG_PLAYER].texture, 0, 5, 5, 0 }

    for !rl.WindowShouldClose() {
        // Game time control ----------------
        gt.currentTime = time.now()._nsec
        gt.realTimeStep =  gt.currentTime - gt.previousTime
        gt.totalGameTime += gt.realTimeStep
        gt.previousTime = gt.currentTime
        gt.lag_accumulator += f64(gt.realTimeStep)
        // ----------------
        input = get_input()
        for(gt.lag_accumulator >= gt.fixed_update_interval) {
           update(gt)
           gt.lag_accumulator -= gt.fixed_update_interval
        }
        render(gt)
    }
}

init_game_data :: proc() {
    game_data.is_running = false
	sprites := make([dynamic]SpriteStruct, len(FILE_NAMES), len(FILE_NAMES))
	game_data.version = "0.0.2"
	game_data.sprites = sprites
	game_data.camera = get_camera(WINDOW_WIDTH, WINDOW_HEIGHT)
	game_data.font = rl.LoadFont(FONT_FILE)
	load_textures(&game_data.sprites)
	game_data.sounds = make([dynamic]rl.Sound,len(SOUND_FILES),len(SOUND_FILES))
	load_sounds(&game_data.sounds)
	game_data.current_max_record = get_max_record()
}

start_game :: proc() {
    game_data.is_running = true
    player.position = {100,44}
    player.score = 0
    player.lives = 5
    player.player_remaining_bullets = 5
    clear(&game_data.enemies_alive)
    clear(&game_data.bullets_alive)
    clear(&game_data.torpedos_alive)
    clear(&game_data.explosions)
}

load_textures :: proc(data: ^[dynamic]SpriteStruct) {
	cnt: int = len(FILE_NAMES)
	for i := 0; i < cnt; i += 1 {
		texture_full_path : string = fmt.tprint(PATH_TEXTURES , FILE_NAMES[i], sep = "")
		texture_full_path_c : cstring = strings.clone_to_cstring(texture_full_path)
		defer delete(texture_full_path_c)
		the_sprite : SpriteStruct
		the_sprite.texture = rl.LoadTexture(texture_full_path_c)
		data[i] = the_sprite
	}
}

load_sounds :: proc(data: ^[dynamic]rl.Sound) {
    cnt: int = len(SOUND_FILES)
    for i := 0; i < cnt; i += 1 {
        sound_full_path : cstring =  fmt.ctprintf("%s%s",PATH_SOUNDS,SOUND_FILES[i])
        the_sound : rl.Sound = rl.LoadSound(sound_full_path);
        data[i] = the_sound
    }
}

delete_gamedata :: proc () {
    for e,i in game_data.sounds{
        rl.UnloadSound(game_data.sounds[i])
    }
    delete(game_data.sprites)
    delete(game_data.bullets_alive)
    delete(game_data.enemies_alive)
    delete(game_data.torpedos_alive)
    delete(game_data.explosions)
    delete(game_data.sounds)
}

get_camera :: proc(width, height: c.int) -> rl.Camera2D {
    camera : rl.Camera2D
    camera.target = rl.Vector2 { (f32)(width/2) , (f32)(height/2) }
    camera.offset = rl.Vector2 { (f32)(width/2) , (f32)(height/2) }
    camera.rotation = 0
    camera.zoom = 1
    return camera
}

update :: proc(gameTime : glue.GameTime) {
    if !game_data.is_running {
        return
    }
    if player.lives<=0 {
        if player.score > uint(game_data.current_max_record) {
            game_data.current_max_record = int(player.score)
            save_max_record( player.score  )
        }
        play_sound(SND_GAME_OVER)
        game_data.is_running = false
        return
    }
    fixed_time_seconds : f32 = f32(gameTime.fixed_update_interval * glue.NS_TO_S)
    new_player_position : rl.Vector2 = player.position
    new_player_position += linalg.normalize0(input) * f32(fixed_time_seconds) * player.velocity
    if new_player_position.x > 0 &&  (new_player_position.x+f32(player.sprite.width)-6 < f32(WINDOW_WIDTH)) {
        player.position = new_player_position
    }
    update_bullets(fixed_time_seconds)
    update_enemies(fixed_time_seconds)
    update_torpedos(fixed_time_seconds)
    check_bullets_collisions(fixed_time_seconds)
    update_effects(fixed_time_seconds)
    check_mines_collisions(fixed_time_seconds)
    spawm_enemy(fixed_time_seconds)
}

update_effects :: proc(fixed_time_step : f32) {
    i : int = 0
    for i < len(game_data.explosions) {
        if game_data.explosions[i].duration <= 0 {
            unordered_remove(&game_data.explosions,i)
        } else {
            game_data.explosions[i].duration -= fixed_time_step
            i += 1
        }
    }
}

check_mines_collisions :: proc(fixed_time_step:f32) {
    // this calcs collisions beetween enemy torpedos and our ship
    bullet_rect : rl.Rectangle = {}
    our_ship_rect : rl.Rectangle = {}
    collide : bool = false
    our_ship_rect =  { player.position.x,
                       player.position.y,
                       f32(player.sprite.width), f32(player.sprite.height)
                     }
    for torpedo, itorpedo in game_data.torpedos_alive {
        if torpedo.delete == true {
            continue
        }
        bullet_rect = { torpedo.position.x - f32(game_data.sprites[IMG_TORPEDO].texture.width) / 2,
                        torpedo.position.y - f32(game_data.sprites[IMG_TORPEDO].texture.height) / 2,
                        f32(game_data.sprites[IMG_TORPEDO].texture.width),
                        f32(game_data.sprites[IMG_TORPEDO].texture.height) }
        collide = rl.CheckCollisionRecs(bullet_rect, our_ship_rect)
        if collide {
            player.lives -= 1
            game_data.torpedos_alive[itorpedo].delete = true
            play_sound(SND_PLAYER_HIT)
        }
    }
}

check_bullets_collisions :: proc(fixed_time_step:f32) {
    // this calcs collisions beetween our bullets and the enemies
    bullet_rect : rl.Rectangle = {}
    enemy_rect : rl.Rectangle = {}
    collide : bool = false
    for bullet, ibullet in game_data.bullets_alive {
        bullet_rect = { bullet.position.x - f32(game_data.sprites[IMG_BULLET].texture.width) / 2,
                        bullet.position.y - f32(game_data.sprites[IMG_BULLET].texture.height) / 2,
                        2 + f32(game_data.sprites[IMG_BULLET].texture.width),
                        2 + f32(game_data.sprites[IMG_BULLET].texture.height) }
        for enemy, ienemy in game_data.enemies_alive {
            enemy_rect = {  enemy.position.x - f32(game_data.sprites[IMG_ENEMY].texture.width) / 2,
                            enemy.position.y - f32(game_data.sprites[IMG_ENEMY].texture.height) / 2,
                            f32(game_data.sprites[IMG_ENEMY].texture.width),
                            f32(game_data.sprites[IMG_ENEMY].texture.height) }
            collide = rl.CheckCollisionRecs(bullet_rect, enemy_rect)
            if collide {
                player.score += 10
                game_data.enemies_alive[ienemy].delete = true
                game_data.bullets_alive[ibullet].delete = true
                t : ExplosionStruct = { {enemy.position.x, enemy.position.y} , .6  }
                _ , err := append(&game_data.explosions,t)
                assert(err==nil)
                play_sound(SND_ENEMY_EXPLOSION)
            }
        }
    }
}

render_start_screen :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground(WINDOW_BACKCOLOR)
    rl.BeginMode2D(game_data.camera)
    rl.DrawTextureV(game_data.sprites[IMG_BACKGROUND].texture, {0,0}, rl.WHITE) // draw this first (it convers all screen)
    rl.DrawTexture(game_data.sprites[IMG_START_SCREEN].texture,20,0,rl.WHITE)
    rl.DrawText( "Current Record:", 200, 500, 40, rl.BLACK)
    rl.DrawText( fmt.ctprintf("%d", game_data.current_max_record) , 200, 550, 48, rl.RED)
    rl.EndMode2D()
    rl.EndDrawing()
}

render :: proc(gameTime : glue.GameTime) {
    if ! game_data.is_running {
        render_start_screen()
        return
    }

    rl.BeginDrawing()
    rl.ClearBackground(WINDOW_BACKCOLOR)

    rl.BeginMode2D(game_data.camera)
    rl.DrawTextureV(game_data.sprites[IMG_BACKGROUND].texture, {0,0}, rl.WHITE) // draw this first (it convers all screen)

    rl.DrawTextEx(game_data.font, "Score", { 8.0, f32(WINDOW_HEIGHT - 200) }, 40, 2, rl.BLACK);
    rl.DrawTextEx(game_data.font, fmt.ctprintf("%d", player.score), { 8.0, f32(WINDOW_HEIGHT - 160) }, 40, 2, rl.BLACK);
    rl.DrawTextEx(game_data.font, "<-,-> : Move", { f32(WINDOW_WIDTH)-140, f32(WINDOW_HEIGHT - 60) }, 16, 2, rl.BLACK);
    rl.DrawTextEx(game_data.font, "Q,A : Fire", { f32(WINDOW_WIDTH)-140, f32(WINDOW_HEIGHT - 30) }, 16, 2, rl.BLACK);

    rl.DrawTextureV(player.sprite, player.position, rl.WHITE)
    when DRAW_HITBOXES {
        player_rect : rl.Rectangle = {
                        player.position.x,
                        player.position.y,
                        f32(player.sprite.width),
                        f32(player.sprite.height) }
        rl.DrawRectangleLinesEx(player_rect, 2, rl.RED)
    }

    draw_fire_cooldown(gameTime)

    for e in game_data.enemies_alive {
        source : rl.Rectangle = {0, 0, (f32)(game_data.sprites[IMG_ENEMY].texture.width), (f32)(game_data.sprites[IMG_ENEMY].texture.height) }
        source.width = source.width if e.direction == { -1, 0 } else source.width * -1 // flip texture according to direction
        dest : rl.Rectangle = {e.position.x, e.position.y, (f32)(game_data.sprites[IMG_ENEMY].texture.width), (f32)(game_data.sprites[IMG_ENEMY].texture.height) }
        origin : rl.Vector2 =  {  (f32)(game_data.sprites[IMG_ENEMY].texture.width/2) , (f32)(game_data.sprites[IMG_ENEMY].texture.height/2)  }
        rl.DrawTexturePro(
            game_data.sprites[2].texture, // texture: Texture2D
            source,                       // source: Rectangle
            dest,                         // dest: Rectangle
            origin,                       // origin: Vector2
            0,                            // rotation: f32
            rl.BROWN if e.delete else rl.WHITE  ) // tint: Color
        when DRAW_HITBOXES {
            enemy_rect : rl.Rectangle = {
                           e.position.x - f32(game_data.sprites[IMG_ENEMY].texture.width)/2 ,
                           e.position.y - f32(game_data.sprites[IMG_ENEMY].texture.height) / 2,
                           f32(game_data.sprites[IMG_ENEMY].texture.width),
                           f32(game_data.sprites[IMG_ENEMY].texture.height) }
            rl.DrawRectangleLinesEx(enemy_rect, 2, rl.RED)
        }
    }

    for b in game_data.bullets_alive {
        source : rl.Rectangle = {0, 0, (f32)(game_data.sprites[IMG_BULLET].texture.width), (f32)(game_data.sprites[IMG_BULLET].texture.height) }
        dest : rl.Rectangle = {b.position.x, b.position.y, (f32)(game_data.sprites[IMG_BULLET].texture.width), (f32)(game_data.sprites[IMG_BULLET].texture.height) }
        origin : rl.Vector2 =  {  (f32)(game_data.sprites[IMG_BULLET].texture.width/2) , (f32)(game_data.sprites[IMG_BULLET].texture.height/2)  }
        rl.DrawTexturePro(
            game_data.sprites[3].texture, // texture: Texture2D
            source,                       // source: Rectangle
            dest,                         // dest: Rectangle
            origin,                       // origin: Vector2
            b.rotation,                   // rotation: f32
            rl.BROWN if b.delete else rl.WHITE  ) // tint: Color

        when DRAW_HITBOXES {
            bullet_rect : rl.Rectangle = {
                            b.position.x - f32(game_data.sprites[IMG_BULLET].texture.width) / 2,
                            b.position.y - f32(game_data.sprites[IMG_BULLET].texture.height) / 2,
                            2 + f32(game_data.sprites[IMG_BULLET].texture.width),
                            2 + f32(game_data.sprites[IMG_BULLET].texture.height) }
            rl.DrawRectangleLinesEx(bullet_rect, 2, rl.RED)
        }
    }

    for t in game_data.torpedos_alive {
        source : rl.Rectangle = {0, 0, (f32)(game_data.sprites[IMG_TORPEDO].texture.width), (f32)(game_data.sprites[IMG_TORPEDO].texture.height) }
        dest : rl.Rectangle = {t.position.x, t.position.y, (f32)(game_data.sprites[IMG_TORPEDO].texture.width), (f32)(game_data.sprites[IMG_TORPEDO].texture.height) }
        origin : rl.Vector2 =  {  (f32)(game_data.sprites[IMG_TORPEDO].texture.width/2) , (f32)(game_data.sprites[IMG_TORPEDO].texture.height/2)  }
        rl.DrawTexturePro(
            game_data.sprites[4].texture, // texture: Texture2D
            source,                       // source: Rectangle
            dest,                         // dest: Rectangle
            origin,                       // origin: Vector2
            0,                            // rotation: f32
            rl.WHITE )                    // tint: Color
        when DRAW_HITBOXES {
            torpedo_rect : rl.Rectangle = {
                            t.position.x - f32(game_data.sprites[IMG_TORPEDO].texture.width) / 2,
                            t.position.y - f32(game_data.sprites[IMG_TORPEDO].texture.height) / 2,
                            2 + f32(game_data.sprites[IMG_TORPEDO].texture.width),
                            2 + f32(game_data.sprites[IMG_TORPEDO].texture.height) }
            rl.DrawRectangleLinesEx(torpedo_rect, 2, rl.RED)
        }

    }

    draw_radar()
    draw_player_live()
    draw_effects()

    rl.EndMode2D()
    gluerl.console_draw()
    rl.EndDrawing()
}

draw_effects :: proc() {
    for effect in game_data.explosions {
        rl.DrawTexture( game_data.sprites[IMG_ENEMY_EXPLOSION].texture,
                        c.int(effect.position.x) - (game_data.sprites[IMG_ENEMY_EXPLOSION].texture.width / 2),
                        c.int(effect.position.y) - (game_data.sprites[IMG_ENEMY_EXPLOSION].texture.height / 2),
                        rl.WHITE )
    }
}

draw_player_live :: proc() {
    MAX_LIVES := 5
    lives_position : rl.Vector2 = {2,2}
    for i in 0..<MAX_LIVES {
        if player.lives > i {
            rl.DrawTexture(game_data.sprites[IMG_HEART_RED].texture , c.int(lives_position.x), c.int(lives_position.y), rl.WHITE)
        } else {
            rl.DrawTexture(game_data.sprites[IMG_HEART_GRAY].texture , c.int(lives_position.x), c.int(lives_position.y), rl.WHITE)
        }
        lives_position.x += 28
    }
}

draw_radar :: proc () {
    radar_x : f32 = 287
    radar_y : f32 = 823
    radar_width : f32 = 236
    radar_height : f32 = 176

    // player
    player_pos_in_radar : rl.Vector2 = {}
    player_pos_in_radar.x = radar_x + (player.position.x  / f32(WINDOW_WIDTH) * radar_width )
    player_pos_in_radar.y =  radar_y-10
    rl.DrawTexture(game_data.sprites[IMG_PLAYER_IN_RADAR].texture, c.int(player_pos_in_radar.x), c.int(player_pos_in_radar.y), rl.GREEN )

    // enemies
    enemy_pos_in_radar : rl.Vector2 = {}
    for e in game_data.enemies_alive {
        enemy_pos_in_radar.x =  radar_x + (e.position.x  / f32(WINDOW_WIDTH) * radar_width )
        enemy_pos_in_radar.y =  radar_y + ( (e.position.y-90)  / f32(WINDOW_WIDTH-90) * radar_height )
        if enemy_pos_in_radar.x >= radar_x && enemy_pos_in_radar.x <= radar_x+radar_width - f32(game_data.sprites[IMG_ENEMY_IN_RADAR].texture.width) {
            rl.DrawTexture(game_data.sprites[IMG_ENEMY_IN_RADAR].texture, c.int(enemy_pos_in_radar.x), c.int(enemy_pos_in_radar.y), rl.GREEN )
        }
    }

    // player bullets
    bullet_pos_in_radar : rl.Vector2 = {}
    for e in game_data.bullets_alive {
        bullet_pos_in_radar.x = radar_x + (e.position.x  / f32(WINDOW_WIDTH) * radar_width )
        bullet_pos_in_radar.y = radar_y + ( (e.position.y-90)  / f32(WINDOW_WIDTH-90) * radar_height )
        rl.DrawTexture(game_data.sprites[IMG_BULLET_IN_RADAR].texture, c.int(bullet_pos_in_radar.x), c.int(bullet_pos_in_radar.y), rl.RED )
    }

    // enemy bullets
    mine_pos_in_radar : rl.Vector2 = {}
    for e in game_data.torpedos_alive {
        mine_pos_in_radar.x = radar_x + (e.position.x  / f32(WINDOW_WIDTH) * radar_width )
        mine_pos_in_radar.y = radar_y + ( (e.position.y-90)  / f32(WINDOW_WIDTH-90) * radar_height )
        if mine_pos_in_radar.x >= radar_x && mine_pos_in_radar.x <= radar_x+radar_width - f32(game_data.sprites[IMG_ENEMY_IN_RADAR].texture.width) {
            rl.DrawTexture(game_data.sprites[IMG_MINE_IN_RADAR].texture, c.int(mine_pos_in_radar.x), c.int(mine_pos_in_radar.y), rl.YELLOW )
        }
    }

}

update_bullets :: proc(fixed_time_step : f32) {
    i : int = 0
    for i < len(game_data.bullets_alive) {
        if game_data.bullets_alive[i].position.y > (f32)(WINDOW_HEIGHT-200) || game_data.bullets_alive[i].delete == true { // 200px is the radar area size
            unordered_remove(&game_data.bullets_alive,i)
            //player_recover_bullet()
        } else {
            game_data.bullets_alive[i].position = game_data.bullets_alive[i].position +
                                                  (game_data.bullets_alive[i].direction * fixed_time_step * game_data.bullets_alive[i].velocity)
            rot : f32 = 20 * fixed_time_step
            game_data.bullets_alive[i].rotation += rot
            i += 1
        }
    }

    // cooldown
    if player.time_to_cooldown > PLAYER_RECOVERY_COOLDOWN {
        player.player_remaining_bullets = player.player_remaining_bullets+1 if player.player_remaining_bullets < PLAYER_MAX_BULLETS else PLAYER_MAX_BULLETS
        player.time_to_cooldown = 0
    } else {
        player.time_to_cooldown += fixed_time_step
    }
}

update_torpedos :: proc(fixed_time_step : f32) {
    i : int = 0
    for i < len(game_data.torpedos_alive) {
        if game_data.torpedos_alive[i].position.y < (player.position.y + f32(player.sprite.height + 4)) || (game_data.torpedos_alive[i].delete == true) {
            unordered_remove(&game_data.torpedos_alive,i)
        } else {
            game_data.torpedos_alive[i].position = game_data.torpedos_alive[i].position +
                                                   (game_data.torpedos_alive[i].direction * fixed_time_step * game_data.torpedos_alive[i].velocity)
            i += 1
        }
    }
}

update_enemies :: proc(fixed_time_step:f32) {
    i : int = 0
    for i < len(game_data.enemies_alive) {
        if (game_data.enemies_alive[i].position.x > (f32)(WINDOW_WIDTH)+300  || game_data.enemies_alive[i].position.x < -300) || (game_data.enemies_alive[i].delete == true) {
            unordered_remove(&game_data.enemies_alive,i)
        } else {
            game_data.enemies_alive[i].position = game_data.enemies_alive[i].position +
                                                  (game_data.enemies_alive[i].direction * fixed_time_step * game_data.enemies_alive[i].velocity)
            rot : f32 = 20 * fixed_time_step
            if game_data.enemies_alive[i].lastFire >= (game_data.enemies_alive[i].fireEvery / glue.MS_TO_S)  {
                game_data.enemies_alive[i].lastFire = 0
                enemy_fire(fixed_time_step, game_data.enemies_alive[i] )
            } else  {
                 game_data.enemies_alive[i].lastFire += fixed_time_step
            }
            i += 1
        }
    }
}

enemy_fire :: proc (fixed_time_step : f32, enemy : EnemyStruct ) {
    t : TorpedoStruc = { {enemy.position.x, enemy.position.y-20} , {0,-1}, 10, false  }
    _ , err := append(&game_data.torpedos_alive,t)
    assert(err==nil)
}

get_input :: proc() -> (input : rl.Vector2) {
    if rl.IsKeyReleased(.SPACE)
    {
        if !game_data.is_running {
            start_game()
        }
    }
    // if rl.IsKeyDown(.UP) {
    //     input.y -= 1
    // }
    // if rl.IsKeyDown(.DOWN) {
    //     input.y += 1
    // }
    if rl.IsKeyDown(.LEFT) {
        input.x -= 1
    }
    if rl.IsKeyDown(.RIGHT) {
        input.x += 1
    }

    if rl.IsKeyReleased(.Q) {
        player_fire({0,24})
    }
    if rl.IsKeyReleased(.W) {
        player_fire({146,24})
    }
    return;
}

draw_fire_cooldown :: proc (gameTime : glue.GameTime) {
    cool_down_hud_pos : rl.Vector2 = { f32((WINDOW_WIDTH/2)-100),6}
    for i in 0..<PLAYER_MAX_BULLETS {
        if i<player.player_remaining_bullets {
            rl.DrawTextureV(game_data.sprites[IMG_BULLET].texture,cool_down_hud_pos,rl.WHITE)
        } else {
            rl.DrawTextureV(game_data.sprites[IMG_BULLET_COOLDOWN].texture,cool_down_hud_pos,rl.WHITE)
        }
        cool_down_hud_pos.x += 24
    }
}

player_fire :: proc(position : rl.Vector2) {
    if player.player_remaining_bullets == 0 {
        return
    }
    fire_pos : rl.Vector2 = position + player.position
    b : BulletStruct = { fire_pos ,{0,+1}, 60, 0, false}
    _ , err := append(&game_data.bullets_alive,b)
    assert(err==nil)
    player.player_remaining_bullets -= 1
    player.time_to_cooldown = 0
    play_sound(SND_PLAYER_FIRE)
}

spawm_enemy :: proc (fixed_time_seconds : f32) {
    if len(game_data.enemies_alive) >= MAX_ENEMIES {
        return
    }
    time_accumulator += fixed_time_seconds
    if time_accumulator > SPAWM_ENEMY_EVERY_SECONDS {
        time_accumulator = 0
        random_x : int = rand.int_max(100)
        random_y : int = rand.int_max(int(WINDOW_WIDTH)-(90+24+20)+1)+90+24+20 // 24 is half size of sprite enemy, 20 the minimun distance to our ship
        random_y = random_y if random_y<=int(WINDOW_WIDTH)-24 else random_y-14 // 14 is the minimum distance to the radar area
        pos_x : f32 = f32(WINDOW_WIDTH) if random_x < 50 else 0
        pos_y : f32 = f32(random_y)
        position : rl.Vector2 ={pos_x, pos_y}
        direction : rl.Vector2 = {+1,0} if random_x>50 else {-1,0}
        random_fire_spawn : int = rand.int_max(5)+2
        b : EnemyStruct = { position ,direction, ENEMY_VELOCITY_DEFAUL, 0, f32(random_fire_spawn) * glue.MS_TO_S, false}
        _ , err : = append(&game_data.enemies_alive,b)
        assert(err==nil)
        time_since_last_spawn -= SPAWM_ENEMY_EVERY_SECONDS
    }

}

play_sound :: proc( sound_id : int ) {
    if !PLAY_SOUND {
        return
    }
    rl.PlaySound(game_data.sounds[sound_id])
}

get_max_record :: proc() -> int {
    data, err := os.read_entire_file(MAX_SCORE_FILE, context.allocator)
    assert(err == nil)
    if err != nil {
        fmt.println("Error reading file")
    }
    defer delete(data, context.allocator)
    it := string(data)
    max_record : string = ""
    for line in strings.split_lines_iterator(&it) {
        max_record = line // we take only the first line
        break
    }
    max_record_i, ok := strconv.parse_int(max_record, 10)
    assert(ok == true)
    return max_record_i
}

save_max_record :: proc( record: uint ) {
    data_as_string := fmt.tprintf("%d", record)
    data_as_bytes := transmute([]byte)(data_as_string)
    ok := os.write_entire_file(MAX_SCORE_FILE, data_as_bytes)
    assert( ok == nil)
    if ok != nil {
         fmt.println("Error writing file")
     }
}
