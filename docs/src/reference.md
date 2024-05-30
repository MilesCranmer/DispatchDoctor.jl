# Reference

## Macros

```@docs
@stable
@unstable
```

## Utilities

If you wish to turn off `@stable` for a single function call,
you can use `allow_unstable`:

```@docs
allow_unstable
```

`@stable` will normally interact with macros by propagating
them to the function definition as well as the function simulator.
If you would like to change this behavior, or declare a macro as being
incompatible with `@stable`, you can use `register_macro!`:

```@docs
register_macro!
```

## Internals

```@docs
DispatchDoctor.type_instability
```
