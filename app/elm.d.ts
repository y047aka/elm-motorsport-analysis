declare module "*.elm" {
  export const Elm: {
    Main: {
      init(options: { node: HTMLElement | null; flags?: unknown }): unknown;
    };
  };
}
