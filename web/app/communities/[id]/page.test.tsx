import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import CommunityTimelinePage from "./page";

vi.mock("next/navigation", () => ({
  useParams: () => ({ id: "1" }),
}));

describe("CommunityTimelinePage", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("should render the initial loading state", () => {
    const pending = new Promise<Response>(() => {});
    vi.spyOn(global, "fetch").mockReturnValue(pending);

    render(<CommunityTimelinePage />);

    expect(screen.getByText("Carregando timeline...")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "← Voltar para comunidades" })).toHaveAttribute(
      "href",
      "/communities",
    );
  });

  it("should show an error when timeline loading fails", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({ ok: false } as Response)
      .mockResolvedValueOnce({ ok: true, json: async () => ({ messages: [] }) } as Response);

    render(<CommunityTimelinePage />);

    expect(await screen.findByText("Não foi possível carregar a timeline da comunidade.")).toBeInTheDocument();
  });

  it("should order messages by most recent date", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ communities: [{ id: 1, name: "Comu", description: "Desc" }] }),
      } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          messages: [
            {
              id: 10,
              content: "Mensagem antiga",
              username: "old-user",
              ai_sentiment_score: 0,
              reaction_count: 0,
              reply_count: 0,
              created_at: "2025-01-01T00:00:00.000Z",
            },
            {
              id: 20,
              content: "Mensagem nova",
              username: "new-user",
              ai_sentiment_score: 0.8,
              reaction_count: 1,
              reply_count: 2,
              created_at: "2025-02-01T00:00:00.000Z",
            },
          ],
        }),
      } as Response);

    render(<CommunityTimelinePage />);

    await screen.findByText("Mensagem nova");

    const threadLinks = await screen.findAllByRole("link", { name: "Ver thread" });
    await waitFor(() => {
      expect(threadLinks[0]).toHaveAttribute("href", "/messages/20?community_id=1");
      expect(threadLinks[1]).toHaveAttribute("href", "/messages/10?community_id=1");
    });
  });

  it("should validate required fields before creating a message", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ communities: [{ id: 1, name: "Comu", description: "Desc" }] }),
      } as Response)
      .mockResolvedValueOnce({ ok: true, json: async () => ({ messages: [] }) } as Response);

    render(<CommunityTimelinePage />);

    const submitButton = await screen.findByRole("button", { name: "Enviar" });
    fireEvent.click(submitButton);

    expect(screen.getByText("Preencha username e conteúdo para criar a mensagem.")).toBeInTheDocument();
  });

  it("should create a new message and clear content on success", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ communities: [{ id: 1, name: "Comu", description: "Desc" }] }),
      } as Response)
      .mockResolvedValueOnce({ ok: true, json: async () => ({ messages: [] }) } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 77,
          content: "My new post",
          user: { id: 10, username: "alice" },
          ai_sentiment_score: -0.5,
          reaction_count: 0,
          reply_count: 0,
          created_at: "2025-03-01T00:00:00.000Z",
        }),
      } as Response);

    render(<CommunityTimelinePage />);

    await screen.findByText("Nenhuma mensagem encontrada para esta comunidade.");

    fireEvent.change(screen.getByPlaceholderText("Username"), { target: { value: "alice" } });
    const contentField = screen.getByPlaceholderText("Conteúdo da mensagem") as HTMLTextAreaElement;
    fireEvent.change(contentField, { target: { value: "My new post" } });
    fireEvent.click(screen.getByRole("button", { name: "Enviar" }));

    expect(await screen.findByText("My new post")).toBeInTheDocument();
    expect(screen.getByText("☹️ Negativo")).toBeInTheDocument();
    await waitFor(() => {
      expect(contentField.value).toBe("");
    });
  });

  it("should show an error when creating a message fails", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ communities: [{ id: 1, name: "Comu", description: "Desc" }] }),
      } as Response)
      .mockResolvedValueOnce({ ok: true, json: async () => ({ messages: [] }) } as Response)
      .mockResolvedValueOnce({ ok: false } as Response);

    render(<CommunityTimelinePage />);

    await screen.findByText("Nenhuma mensagem encontrada para esta comunidade.");

    fireEvent.change(screen.getByPlaceholderText("Username"), { target: { value: "alice" } });
    fireEvent.change(screen.getByPlaceholderText("Conteúdo da mensagem"), { target: { value: "Oops" } });
    fireEvent.click(screen.getByRole("button", { name: "Enviar" }));

    expect(await screen.findByText("Não foi possível criar a mensagem.")).toBeInTheDocument();
  });

  it("should require reaction user id before reacting", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ communities: [{ id: 1, name: "Comu", description: "Desc" }] }),
      } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          messages: [
            {
              id: 10,
              content: "React here",
              username: "user",
              ai_sentiment_score: null,
              reaction_count: 0,
              reply_count: 0,
              created_at: "2025-01-01T00:00:00.000Z",
            },
          ],
        }),
      } as Response);

    render(<CommunityTimelinePage />);

    await screen.findByText("React here");
    fireEvent.click(screen.getByRole("button", { name: "like (0)" }));

    expect(screen.getByText("Informe o ID do usuário para reagir.")).toBeInTheDocument();
  });

  it("should update reaction counters on successful reaction", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ communities: [{ id: 1, name: "Comu", description: "Desc" }] }),
      } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          messages: [
            {
              id: 10,
              content: "React here",
              username: "user",
              ai_sentiment_score: null,
              reaction_count: 0,
              reply_count: 0,
              created_at: "2025-01-01T00:00:00.000Z",
            },
          ],
        }),
      } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ reactions: { like: 2, love: 1, insightful: 3 } }),
      } as Response);

    render(<CommunityTimelinePage />);

    await screen.findByText("React here");
    fireEvent.change(screen.getByPlaceholderText("Ex.: 1"), { target: { value: "2" } });
    fireEvent.click(screen.getByRole("button", { name: "like (0)" }));

    expect(await screen.findByText("Reações: 6")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "like (2)" })).toBeInTheDocument();
  });

  it("should surface API error message when reaction fails", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ communities: [{ id: 1, name: "Comu", description: "Desc" }] }),
      } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          messages: [
            {
              id: 10,
              content: "React here",
              username: "user",
              ai_sentiment_score: null,
              reaction_count: 0,
              reply_count: 0,
              created_at: "2025-01-01T00:00:00.000Z",
            },
          ],
        }),
      } as Response)
      .mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: "Custom reaction error" }),
      } as Response);

    render(<CommunityTimelinePage />);

    await screen.findByText("React here");
    fireEvent.change(screen.getByPlaceholderText("Ex.: 1"), { target: { value: "2" } });
    fireEvent.click(screen.getByRole("button", { name: "like (0)" }));

    expect(await screen.findByText("Custom reaction error")).toBeInTheDocument();
  });

  it("should load more messages when reaching the end of the feed", async () => {
    let onIntersect: ((entries: Array<{ isIntersecting: boolean }>) => void) | undefined;

    class MockIntersectionObserver {
      constructor(callback: (entries: Array<{ isIntersecting: boolean }>) => void) {
        onIntersect = callback;
      }

      observe() {
        return;
      }

      disconnect() {
        return;
      }
    }

    vi.stubGlobal("IntersectionObserver", MockIntersectionObserver);

    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ communities: [{ id: 1, name: "Comu", description: "Desc" }] }),
      } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          messages: [
            {
              id: 10,
              content: "Primeira página",
              username: "user-one",
              ai_sentiment_score: null,
              reaction_count: 0,
              reply_count: 0,
              created_at: "2025-01-01T00:00:00.000Z",
            },
          ],
          pagination: { has_more: true, next_offset: 1 },
        }),
      } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          messages: [
            {
              id: 20,
              content: "Segunda página",
              username: "user-two",
              ai_sentiment_score: null,
              reaction_count: 0,
              reply_count: 0,
              created_at: "2025-01-02T00:00:00.000Z",
            },
          ],
          pagination: { has_more: false, next_offset: 2 },
        }),
      } as Response);

    render(<CommunityTimelinePage />);

    await screen.findByText("Primeira página");
    expect(onIntersect).toBeTypeOf("function");

    if (onIntersect) {
      onIntersect([{ isIntersecting: true }]);
    }

    expect(await screen.findByText("Segunda página")).toBeInTheDocument();
  });
});
