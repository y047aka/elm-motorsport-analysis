// `vite-plugin-elm` creates these modules during the build and ships no
// ambient declaration for them.
declare module "*.elm" {
  export const Elm: Record<
    string,
    {
      init(options: {
        node?: Element | null;
        flags?: unknown;
      }): { ports?: Record<string, unknown> };
    }
  >;
}
