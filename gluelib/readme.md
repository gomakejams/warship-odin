# Custom Odin package to develop my projects

This package has utilities that I use as a template to test things in Odin; it is highly opinionated and adapted to my needs.


To use copy the "gluelib" folder to your project


## Error handlers

```
import glue "gluelib"
```

At main set one of the handlers  :

```
main :: proc() {
    glue.set_crash_handler(glue.crash_handler_type.BACKTRACE)

    // your code here...    
    
    // to test an exception uncomment :
    // back.register_segfault_handler()
    // ptr: ^int
    // bad := ptr^ + 2
    // _ = bad
    
    // to test an assertion uncomment :
    // assert(42 == 73)
    
    // to test an exception in a 3rd party lib 
    // call to a raylib function without calling InitWindow 
    // dont forget : import rl "vendor:raylib" and uncomment :
    // rl.CloseWindow() 
}
```

Handlers can be :

```
glue.crash_handler_type.MINIDUMP // creates a .dmp file for windbg
glue.crash_handler_type.BACKTRACE // shows an stacktrace+line number on crash
glue.crash_handler_type.CUSTOMTEST // a useless handler that I have to test
```

#### The credit for the error handlers goes entirely to : 
- https://github.com/laytan/back
- https://github.com/DaseinPhaos/pdb
- https://github.com/ccll (see : [minidump code here](https://github.com/odin-lang/Odin/issues/4407))

I've only made minor modifications to capture the stack trace when the error occurs outside of Odin in a 3rd party lib (e.g., in raylib).

PS: Backtrace also allows to print tracebacks without need to crash see @laytan repository if you want learn how to use

## print color to console

Simple package to print to console with colors

```
import glueprint "gluelib/printcolor"

main :: proc() { 
   glue.printc("Hola mundo!!",2,"3", color = glue.ERR_COLOR)
   glue.printc("Hola mundo!!",2,"3")
   pc.printc("normal")
   pc.printc_error("error")
   pc.printc_warn("warm")
   pc.printc_info("info")
   pc.printc("normal",color=pc.NORMAL_COLOR)
   pc.printc("error",color=pc.ERR_COLOR)
   pc.printc("warm",color=pc.WARN_COLOR)
   pc.printc("info",color=pc.INFO_COLOR)
}
```

## raylibtools

Package to draw info in a Raylib window like a console

When console_init() is called pass the number of lines you want in it, the you can call console_setline() passing the line number you want to write


```
import rl "vendor:raylib"
import gluerl "gluelib/raylibtools"

main :: proc() {
    rl.InitWindow(800, 600, "Test ...")
    defer rl.CloseWindow()

    gluerl.console_init(800, 600, max_lines=20, color={20,20,20,255})
    defer gluerl.console_delete()
    gluerl.console_show()

    // console_setline can be called any time 
    position : rl.Vector2 = {200,200}
    gluerl.console_setline(0, position , "This is a vector:" )
    gluerl.console_setline(1, cstring("this is a string"), "String:")
    gluerl.console_setline(1, c.int(1000), "This is a int:")
    gluerl.console_setline(1, f64(10.00), "This is a float:")

    rl.BeginDrawing()
    rl.ClearBackground(WINDOW_BACKCOLOR)
    gluerl.console_draw() // but console_draw() must be called between BeginDrawing() and EndDrawing
    rl.EndDrawing()
    
}


```

## gametime

An Odin implementation of a game loop down to nanosecods

Is made following the famous article of Glenn Fiedler : https://gafferongames.com/post/fix_your_timestep/



```
import glue "gluelib"

main :: proc() {
    // Init game time struct
    gt : glue.GameTime ----------------
    gt.startTime = time.now()._nsec
    gt.previousTime = time.now()._nsec
    gt.fixed_update_interval = glue.FIXED_UPDATE_TIMESTEP_60HZ
    gt.lag_accumulator = 0.0
    gt.totalGameTime = 0
    // ----------------

    rl.SetTargetFPS(60)
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "test")
    defer rl.CloseWindow()

    for !rl.WindowShouldClose() {
        // Game time control ----------------
        gt.currentTime = time.now()._nsec
        gt.realTimeStep =  gt.currentTime - gt.previousTime
        gt.totalGameTime += gt.realTimeStep
        gt.previousTime = gt.currentTime
        gt.lag_accumulator += f64(gt.realTimeStep)
        // ----------------
        
        // input = get_input()
        
        for(gt.lag_accumulator >= gt.fixed_update_interval) {
           update(gt)
           gt.lag_accumulator -= gt.fixed_update_interval
        }
        render(gt)
        
    }
    
}


update :: proc(gameTime : glue.GameTime) {
    // we get game time in nanoseconds if you wat use another time slice convert it before use :
    fixed_time_seconds : f32 = f32(gameTime.fixed_update_interval * glue.NS_TO_S)
    fixed_time_miliseconds : f32 = f32(gameTime.fixed_update_interval * glue.NS_TO_MS)

    // update ...
    
}

render :: proc(gameTime : glue.GameTime) { 
    // we get game time in nanoseconds if you wat use another time slice convert it before use :
    fixed_time_seconds : f32 = f32(gameTime.fixed_update_interval * glue.NS_TO_S)
    fixed_time_miliseconds : f32 = f32(gameTime.fixed_update_interval * glue.NS_TO_MS)

    // rendering ...

}
```
