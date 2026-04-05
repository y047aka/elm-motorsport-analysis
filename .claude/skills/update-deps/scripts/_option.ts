// Shared Option type for update-deps scripts.
//
// API:
//   isSome(opt)           — type guard; use when both branches need distinct logic
//   getOrElse(opt, fb)    — unwrap with fallback; use for simple default values
//   fromNullable(v)       — lift T | null | undefined into Option<T>;
//                           use at boundaries where standard-library APIs
//                           (e.g. .at(), .find(), .match()) return T | undefined
//
// match(opt, { some, none }) was considered but not adopted.
// isSome + getOrElse already cover all current use cases, and match would add
// a third choice without enabling anything new. TypeScript's control-flow
// narrowing via if/else is the idiomatic equivalent of pattern matching here.

export type Some<T> = { readonly tag: "some"; readonly value: T };
export type None = { readonly tag: "none" };
export type Option<T> = Some<T> | None;

export const some = <T>(value: T): Some<T> => ({ tag: "some", value });
export const none: None = { tag: "none" };
export const isSome = <T>(opt: Option<T>): opt is Some<T> => opt.tag === "some";
export const getOrElse = <T>(opt: Option<T>, fallback: T): T =>
  isSome(opt) ? opt.value : fallback;
export const fromNullable = <T>(v: T | null | undefined): Option<T> =>
  v != null ? some(v) : none;
