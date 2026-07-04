package gluelib

//import "core:fmt"
//import "core:time"
//import rl "vendor:raylib"

FIXED_UPDATE_TIMESTEP_60HZ : f64 = 16_666_666 // ns
FIXED_UPDATE_TIMESTEP_144HZ : f64 = 6_944_444 // ns
NS_TO_S : f64 = 0.000000001
NS_TO_MS : f64 = 0.000001
MS_TO_S : f32 : 0.0001


GameTime :: struct {
    startTime:             i64, // time start of this struct
    previousTime:          i64,
    currentTime:           i64,
    realTimeStep:          i64,
    lag_accumulator:       f64, // cuánto se está retrasando el reloj del juego respecto al reloj real (acumulador de tiempo pendiente de procesar)
    fixed_update_interval: f64, // usually (16_666_666 ns) for 60hz (1/60) or (6_944_444,44 ns) for 144hz (1/144)
    totalGameTime:         i64, // how much time this struct is alive
}

create_gametime :: proc() -> GameTime {
    gt : GameTime = {}
    return gt
}
