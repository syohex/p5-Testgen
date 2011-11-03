#ifdef unix
#include<stdio.h>
#include<float.h>
#define printok() write(1,"@OK@\n",5)
#define printno() write(1,"@NG@\n",5)
#define printdiv() write(1,"====\n",5)
#define ABS(a) ((a > 0)? (a) : (-(a)))
#define MAX(a, b) ((a > b)? (a) : (b))
#define TGEN_FLT_EQ(a, b) ( ((a)==(b)) || ABS(((a) - (b))) / MAX( ABS(a), ABS(b) ) <= FLT_EPSILON )
#endif
