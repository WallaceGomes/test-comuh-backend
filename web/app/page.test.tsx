import { render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import HomePage from "./page";

describe("HomePage", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("should show an error when the API request fails", async () => {
    vi.spyOn(global, "fetch").mockResolvedValue({ ok: false } as Response);

    const ui = await HomePage();
    render(ui);

    expect(screen.getByText("Não foi possível carregar as comunidades.")).toBeInTheDocument();
  });

  it("should show the empty state when there are no communities", async () => {
    vi.spyOn(global, "fetch").mockResolvedValue({
      ok: true,
      json: async () => ({ communities: [] }),
    } as Response);

    const ui = await HomePage();
    render(ui);

    expect(screen.getByText("Nenhuma comunidade encontrada.")).toBeInTheDocument();
  });

  it("should render communities and use message count fallback", async () => {
    vi.spyOn(global, "fetch").mockResolvedValue({
      ok: true,
      json: async () => ({
        communities: [
          { id: 1, name: "Tech", description: null, message_count: 7 },
          { id: 2, name: "Design", description: "UI e UX", messages_count: 3 },
        ],
      }),
    } as Response);

    const ui = await HomePage();
    render(ui);

    expect(screen.getByText("Tech")).toBeInTheDocument();
    expect(screen.getByText("Sem descrição.")).toBeInTheDocument();
    expect(screen.getByText("Mensagens: 7")).toBeInTheDocument();
    expect(screen.getByText("Mensagens: 3")).toBeInTheDocument();
  });
});
