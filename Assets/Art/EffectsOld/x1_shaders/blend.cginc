#ifdef _EFFECTENUM_COLORADD
col.rgb *= col.a;
col.a = 1;
#elif defined(_EFFECTENUM_ALPHABLEND)
col.rgb *= col.a;
col.a = 1 - col.a;
#elif defined(_EFFECTENUM_LIGHTBLEND1)
col.rgb *= col.a;
col.a = 1 - col.a * col.a;
#elif defined(_EFFECTENUM_LIGHTBLEND2)
col.rgb = lerp(col.rgb * col.a, 1, col.a * col.a * col.a);
col.a = 1 - col.a;
#elif defined(_EFFECTENUM_LIGHTBLEND3)
col.rgb = lerp(col.rgb * col.a, 1, col.a * col.a);
col.a = 1 - col.a;
#endif
