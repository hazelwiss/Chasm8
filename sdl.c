#include<SDL2/SDL.h>

SDL_Window* window;
SDL_Renderer* renderer;
const char* window_title = "my window";
const int w_h_mul = 5;
unsigned int clock_speed = 600;
unsigned int passed_cycles = 0;
const unsigned char* keyboard_state;
unsigned int output_buffer[32*64];

int sdl_init(){
    if(SDL_Init(SDL_INIT_EVERYTHING) != 0){
        printf("error initializing SDL!\n");
        exit(1);
    }
    keyboard_state = SDL_GetKeyboardState(NULL);
    memset(output_buffer, 0, sizeof(output_buffer));
}

void sdl_draw_pixel(int x, int y, int colour){
    SDL_SetRenderDrawColor(renderer, colour, colour, colour, 0xFF);
    SDL_Rect rect = {.x = x*w_h_mul, .y = y*w_h_mul, .w = w_h_mul, .h = w_h_mul};
    SDL_RenderFillRect(renderer, &rect);
}

void sdl_init_window(){
    SDL_CreateWindowAndRenderer(64*w_h_mul, 32*w_h_mul, SDL_WINDOW_SHOWN, 
        &window, &renderer);
    SDL_SetWindowTitle(window, window_title);
    if(window == NULL || renderer == NULL){
        printf("error creating SDL window!\n");
        exit(1);
    }
}

void sdl_poll(char input[16]){
    SDL_Event event;
    while(SDL_PollEvent(&event)){}
    memset(input, 0, 16);
    input[0x0] = keyboard_state[SDL_SCANCODE_0];
    input[0x1] = keyboard_state[SDL_SCANCODE_1];
    input[0x3] = keyboard_state[SDL_SCANCODE_3];
    input[0x5] = keyboard_state[SDL_SCANCODE_5];
    input[0x7] = keyboard_state[SDL_SCANCODE_7];
    input[0x9] = keyboard_state[SDL_SCANCODE_9];
    input[0xA] = keyboard_state[SDL_SCANCODE_Z];
    input[0xB] = keyboard_state[SDL_SCANCODE_X];
    input[0xC] = keyboard_state[SDL_SCANCODE_C];
    input[0xD] = keyboard_state[SDL_SCANCODE_V];
    input[0xE] = keyboard_state[SDL_SCANCODE_B];
    input[0xF] = keyboard_state[SDL_SCANCODE_N];
    input[0x8] = keyboard_state[SDL_SCANCODE_W];
    input[0x4] = keyboard_state[SDL_SCANCODE_A];
    input[0x6] = keyboard_state[SDL_SCANCODE_D];
    input[0x2] = keyboard_state[SDL_SCANCODE_S];
}

void sdl_draw(int height, int y, int x, char* input, char* vf){
    *vf = 0;
    int input_array[32][8];
    for(int h = 0; h < height; ++h){
        for(int bit = 0; bit < 8; ++bit){
            input_array[h][bit] = (input[h]&(0x80>>bit)) != 0;
        }
    }
    unsigned int* iter = output_buffer+x+y*64;
    for(int h = 0; h < height; ++h){
        for(unsigned int bit = 0, *tmp_iter = iter; bit < 8 && x+bit < 64; ++bit, ++tmp_iter){
            int bit_toogle = input_array[h][bit];
            if(bit_toogle){
                if(*tmp_iter){
                    *tmp_iter = 0;
                    *vf = 1;
                } else 
                    *tmp_iter = 0xFFFFFFFF;
            }
        }
        iter+=64;
    }
    SDL_SetRenderDrawColor(renderer,0,0,0,0xFF);
    SDL_RenderClear(renderer);
    for(int h = 0; h < 32; ++h){
        for(int w = 0; w < 64; ++w){
            sdl_draw_pixel(w, h, output_buffer[h*64+w]);
        }
    }
    SDL_RenderPresent(renderer);
}

void sdl_clear_window(){
    memset(output_buffer, 0, sizeof(output_buffer));
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0xFF);
    SDL_RenderClear(renderer);
    SDL_RenderPresent(renderer);
}

void load_rom(char* memory){
    //printf("Please specify rom name...\n");
    char rom_name[0x1000];
    const char* romname = "roms/tetris.ch8";
retry:
    /*fflush(stdin);
    if(scanf("%s", rom_name) == 0){
        printf("couldn't properly read input, please try again!\n");
        goto retry;
    }*/
    memset(rom_name, 0, sizeof(rom_name));
    memcpy(rom_name, romname, strlen(romname));
    FILE* file = 0;
    if((file = fopen(rom_name, "rb")) == NULL){
        printf("incorrect file name given. Please specify again.\n");
        goto retry;
    }
    fseek(file, 0, SEEK_END);
    int size = ftell(file);
    fseek(file, 0, SEEK_SET);
    char tmp_buf[0x1000];
    char* ptr = memory+0x200;
    fread(ptr, size, 1, file);
    fclose(file);
}

//  debug functions

void print_instr(short instr, short pc, char regs[16], short* reg_i, short* sp){
    printf("instr: %04X pc: %04X sp: %04X I: %04X ", instr&0xFFFF, (pc&0xFFFF)-2, (*sp)&0xFFFF, (*reg_i)&0xFFFF);
    for(int i = 0; i < 16; ++i){
        printf("V[%d]: %02X ", i, regs[i]&0xFF);
    }
    printf("\n");
};

void print_memory(char* memory){
    for(int i = 0; i < 0x1000;){
        for(;i%16 != 0; ++i)
            printf("%02Xh ", memory[i] & 0xFF);
        printf("\n");
        if(i == 0){
            printf("0x%X:  ", i/16);
            printf("%02Xh ", memory[0] & 0xFF);
            ++i;
        } else if(i%16 == 0)
            printf("0x%04X:  ", (i/16)&0xFFFF);
        printf("%02Xh ", memory[i] & 0xFF);
        ++i;
    }
}

static inline float milli_to_sec(unsigned long long int milli){
    return ((float)milli)/1000;
}

void wait_timer(char* s_timer, char* d_timer){
    ++passed_cycles;
    if(passed_cycles%60 == 0){
        if(*s_timer > 0)
            --(*s_timer);
        if(*d_timer > 0)
            --(*d_timer);
        SDL_Delay(100);
    }
    if(passed_cycles>clock_speed){
        passed_cycles = 0;
    }
}