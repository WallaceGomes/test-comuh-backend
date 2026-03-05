import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import MessageThreadPage from "./page";

let mockedCommunityId = "1";

vi.mock("next/navigation", () => ({
  useParams: () => ({ id: "99" }),
  useSearchParams: () => ({
    get: (key: string) => (key === "community_id" ? mockedCommunityId : null),
  }),
}));

describe("MessageThreadPage", () => {
  beforeEach(() => {
    localStorage.clear();
    mockedCommunityId = "1";
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("should show fallback when the main message is not found", async () => {
    vi.spyOn(global, "fetch").mockResolvedValue({
      ok: true,
      json: async () => ({
        messages: [
          {
            id: 10,
            content: "Outra mensagem",
            username: "user",
            ai_sentiment_score: null,
            reaction_count: 0,
            reply_count: 0,
            created_at: "2025-01-01T00:00:00.000Z",
          },
        ],
      }),
    } as Response);

    render(<MessageThreadPage />);

    expect(await screen.findByText("Mensagem principal indisponível no momento.")).toBeInTheDocument();
  });

  it("should validate required fields before posting a comment", async () => {
    vi.spyOn(global, "fetch").mockResolvedValue({
      ok: true,
      json: async () => ({ messages: [] }),
    } as Response);

    render(<MessageThreadPage />);

    const submitButton = await screen.findByRole("button", { name: "Comentar" });
    fireEvent.click(submitButton);

    expect(screen.getByText("Preencha community_id, username e conteúdo para comentar.")).toBeInTheDocument();
  });

  it("should persist a created comment in localStorage", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          messages: [
            {
              id: 99,
              content: "Mensagem principal",
              username: "autor",
              ai_sentiment_score: 0,
              reaction_count: 2,
              reply_count: 0,
              created_at: "2025-01-01T00:00:00.000Z",
            },
          ],
        }),
      } as Response)
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 501,
          username: "maria",
          content: "Novo comentário",
          created_at: "2025-02-01T00:00:00.000Z",
        }),
      } as Response);

    render(<MessageThreadPage />);

    await screen.findByText("Mensagem principal");

    fireEvent.change(screen.getByPlaceholderText("Username"), { target: { value: "maria" } });
    fireEvent.change(screen.getByPlaceholderText("Conteúdo do comentário"), {
      target: { value: "Novo comentário" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Comentar" }));

    expect(await screen.findByText("Novo comentário", { selector: "p" })).toBeInTheDocument();

    await waitFor(() => {
      const saved = localStorage.getItem("message:99:comments");
      expect(saved).toContain("Novo comentário");
      expect(saved).toContain("maria");
    });
  });

  it("should show thread loading error when message fetch fails", async () => {
    vi.spyOn(global, "fetch").mockResolvedValue({ ok: false } as Response);

    render(<MessageThreadPage />);

    expect(await screen.findByText("Não foi possível carregar a thread.")).toBeInTheDocument();
  });

  it("should show loading then main message data when available", async () => {
    vi.spyOn(global, "fetch").mockResolvedValue({
      ok: true,
      json: async () => ({
        messages: [
          {
            id: 99,
            content: "Primary post",
            username: "john",
            ai_sentiment_score: 0.9,
            reaction_count: 4,
            reply_count: 1,
            created_at: "2025-03-01T00:00:00.000Z",
          },
        ],
      }),
    } as Response);

    render(<MessageThreadPage />);

    expect(screen.getByText("Carregando mensagem principal...")).toBeInTheDocument();
    expect(await screen.findByText("Primary post")).toBeInTheDocument();
    expect(screen.getByText("😊 Positivo")).toBeInTheDocument();
  });

  it("should show specific API error when comment creation fails", async () => {
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          messages: [
            {
              id: 99,
              content: "Primary post",
              username: "john",
              ai_sentiment_score: null,
              reaction_count: 0,
              reply_count: 0,
              created_at: "2025-03-01T00:00:00.000Z",
            },
          ],
        }),
      } as Response)
      .mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: "Comment API error" }),
      } as Response);

    render(<MessageThreadPage />);

    await screen.findByText("Primary post");
    fireEvent.change(screen.getByPlaceholderText("Username"), { target: { value: "maria" } });
    fireEvent.change(screen.getByPlaceholderText("Conteúdo do comentário"), { target: { value: "Fail" } });
    fireEvent.click(screen.getByRole("button", { name: "Comentar" }));

    expect(await screen.findByText("Comment API error")).toBeInTheDocument();
  });

  it("should keep form disabled text while submitting comment", async () => {
    const pendingCommentRequest = new Promise<Response>(() => {});
    vi.spyOn(global, "fetch")
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          messages: [
            {
              id: 99,
              content: "Primary post",
              username: "john",
              ai_sentiment_score: null,
              reaction_count: 0,
              reply_count: 0,
              created_at: "2025-03-01T00:00:00.000Z",
            },
          ],
        }),
      } as Response)
      .mockReturnValueOnce(pendingCommentRequest);

    render(<MessageThreadPage />);

    await screen.findByText("Primary post");
    fireEvent.change(screen.getByPlaceholderText("Username"), { target: { value: "maria" } });
    fireEvent.change(screen.getByPlaceholderText("Conteúdo do comentário"), { target: { value: "Pending" } });
    fireEvent.click(screen.getByRole("button", { name: "Comentar" }));

    expect(await screen.findByRole("button", { name: "Enviando..." })).toBeInTheDocument();
  });

  it("should handle empty community id from query and validate form", async () => {
    mockedCommunityId = "";

    render(<MessageThreadPage />);

    expect(await screen.findByText("Mensagem principal indisponível no momento.")).toBeInTheDocument();
    fireEvent.change(screen.getByPlaceholderText("Username"), { target: { value: "maria" } });
    fireEvent.change(screen.getByPlaceholderText("Conteúdo do comentário"), { target: { value: "No community" } });
    fireEvent.click(screen.getByRole("button", { name: "Comentar" }));

    expect(screen.getByText("Preencha community_id, username e conteúdo para comentar.")).toBeInTheDocument();
  });
});
