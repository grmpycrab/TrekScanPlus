import { useEffect, useRef, useState } from "react";

/**
 * Hook to bind a ViewModel instance to React state.
 * Expects the ViewModel to implement subscribe(listener) and getState().
 * Returns the current state from getState().
 */
export function useViewModel(viewModel) {
  const lastVmRef = useRef(null);
  const [state, setState] = useState(() => {
    return viewModel && typeof viewModel.getState === "function"
      ? viewModel.getState()
      : {};
  });

  useEffect(() => {
    // Only resubscribe when the instance changes
    if (lastVmRef.current === viewModel) return;
    lastVmRef.current = viewModel;

    if (!viewModel || typeof viewModel.subscribe !== "function") {
      return;
    }

    let isActive = true;

    // Subscribe to ViewModel state changes
    const unsubscribe = viewModel.subscribe((nextState) => {
      if (!isActive) return;
      setState((prev) => (prev === nextState ? prev : nextState));
    });

    // Sync once in case state changed before effect
    if (typeof viewModel.getState === "function") {
      const current = viewModel.getState();
      setState((prev) => (prev === current ? prev : current));
    }

    return () => {
      isActive = false;
      if (typeof unsubscribe === "function") {
        unsubscribe();
      }
    };
  }, [viewModel]);

  return state;
}
