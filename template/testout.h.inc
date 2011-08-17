@def $testout()
#ifdef unix
#include<stdio.h>
#include<float.h>
#define printok() printf("@OK@\n")
#define printno() printf("@NG@\n")
#define ABS(a) ((a > 0)? (a) : (-(a)))
#define MAX(a, b) ((a > b)? (a) : (b))
#define TGEN_FLT_EQ(a, b) ( ((a)==(b)) || ABS(((a) - (b))) / MAX( ABS(a), ABS(b) ) <= FLT_EPSILON )
#endif
@def_
