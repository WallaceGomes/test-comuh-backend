"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { FormEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";

type Community = {
  id: number;
  name: string;
  description: string | null;
};

type Message = {
  id: number;
  content: string;
  user?: { id: number; username: string };
  username?: string;
  ai_sentiment_score: number | null;
  reaction_count: number;
  reply_count: number;
  created_at?: string;
  reactions?: {
    like: number;
    love: number;
    insightful: number;
  };
};

type ReactionType = "like" | "love" | "insightful";

const DEFAULT_REACTIONS = { like: 0, love: 0, insightful: 0 };
const PAGE_SIZE = 20;

function sentimentLabel(score: number | null): string {
  if (score == null) return "😐 Neutro";
  if (score > 0.2) return "😊 Positivo";
  if (score < -0.2) return "☹️ Negativo";
  return "😐 Neutro";
}

function normalizeMessage(raw: Message): Message {
  const fallbackTotal = raw.reaction_count ?? 0;
  return {
    ...raw,
    username: raw.user?.username ?? raw.username ?? "desconhecido",
    reaction_count: fallbackTotal,
    reply_count: raw.reply_count ?? 0,
    reactions: raw.reactions ?? { ...DEFAULT_REACTIONS, like: fallbackTotal },
  };
}

function mergeUniqueMessages(current: Message[], incoming: Message[]): Message[] {
  if (incoming.length === 0) return current;

  const existingIds = new Set(current.map((message) => message.id));
  const next = [...current];

  for (const message of incoming) {
    if (existingIds.has(message.id)) continue;
    next.push(message);
    existingIds.add(message.id);
  }

  return next;
}

export default function CommunityTimelinePage() {
  const params = useParams<{ id: string }>();
  const communityId = Number(params.id);
  const apiBaseUrl = useMemo(() => {
    if (process.env.NEXT_PUBLIC_API_BASE_URL) {
      return process.env.NEXT_PUBLIC_API_BASE_URL;
    }

    if (typeof window !== "undefined") {
      return `${window.location.protocol}//${window.location.hostname}:3000/api/v1`;
    }

    return "http://localhost:3000/api/v1";
  }, []);

  const [community, setCommunity] = useState<Community | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMoreMessages, setHasMoreMessages] = useState(false);
  const [nextOffset, setNextOffset] = useState(0);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const loadMoreRef = useRef<HTMLDivElement | null>(null);

  const [username, setUsername] = useState("");
  const [content, setContent] = useState("");
  const [reactionUserId, setReactionUserId] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const orderedMessages = useMemo(() => {
    return [...messages].sort((a, b) => {
      const dateA = a.created_at ? new Date(a.created_at).getTime() : 0;
      const dateB = b.created_at ? new Date(b.created_at).getTime() : 0;
      return dateB - dateA;
    });
  }, [messages]);

  const fetchMessagesPage = useCallback(
    async (offset: number) => {
      const response = await fetch(
        `${apiBaseUrl}/communities/${communityId}/messages/top?limit=${PAGE_SIZE}&offset=${offset}`,
        { cache: "no-store" },
      );

      if (!response.ok) {
        throw new Error("Falha ao carregar dados da comunidade.");
      }

      const payload = await response.json();
      const list: Message[] = Array.isArray(payload.messages)
        ? payload.messages.map((message: Message) => normalizeMessage(message))
        : [];

      const pagination = payload.pagination;
      const fallbackNextOffset = offset + list.length;

      return {
        list,
        hasMore:
          typeof pagination?.has_more === "boolean"
            ? pagination.has_more
            : list.length === PAGE_SIZE,
        nextOffset:
          typeof pagination?.next_offset === "number"
            ? pagination.next_offset
            : fallbackNextOffset,
      };
    },
    [apiBaseUrl, communityId],
  );

  const loadMoreMessages = useCallback(async () => {
    if (isLoading || isLoadingMore || !hasMoreMessages) return;

    setIsLoadingMore(true);
    try {
      const page = await fetchMessagesPage(nextOffset);
      setMessages((current) => mergeUniqueMessages(current, page.list));
      setHasMoreMessages(page.hasMore);
      setNextOffset(page.nextOffset);
    } catch {
      setErrorMessage("Não foi possível carregar mais mensagens.");
    } finally {
      setIsLoadingMore(false);
    }
  }, [fetchMessagesPage, hasMoreMessages, isLoading, isLoadingMore, nextOffset]);

  useEffect(() => {
    let isMounted = true;

    async function loadPageData() {
      setIsLoading(true);
      setErrorMessage(null);

      try {
        const [communitiesResponse, messagesResponse] = await Promise.all([
          fetch(`${apiBaseUrl}/communities`, { cache: "no-store" }),
          fetch(`${apiBaseUrl}/communities/${communityId}/messages/top?limit=${PAGE_SIZE}&offset=0`, {
            cache: "no-store",
          }),
        ]);

        if (!communitiesResponse.ok || !messagesResponse.ok) {
          throw new Error("Falha ao carregar dados da comunidade.");
        }

        const communitiesData = await communitiesResponse.json();
        const messagesData = await messagesResponse.json();

        if (!isMounted) return;

        const allCommunities: Community[] = Array.isArray(communitiesData.communities)
          ? communitiesData.communities
          : [];

        const selectedCommunity = allCommunities.find((item) => item.id === communityId) || null;
        setCommunity(selectedCommunity);

        const list: Message[] = Array.isArray(messagesData.messages)
          ? messagesData.messages.map((message: Message) => normalizeMessage(message))
          : [];
        setMessages(list);

        const pagination = messagesData.pagination;
        setHasMoreMessages(
          typeof pagination?.has_more === "boolean" ? pagination.has_more : list.length === PAGE_SIZE,
        );
        setNextOffset(
          typeof pagination?.next_offset === "number" ? pagination.next_offset : list.length,
        );
      } catch {
        if (isMounted) {
          setErrorMessage("Não foi possível carregar a timeline da comunidade.");
        }
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    }

    if (!Number.isNaN(communityId)) {
      loadPageData();
    }

    return () => {
      isMounted = false;
    };
  }, [apiBaseUrl, communityId]);

  useEffect(() => {
    if (!hasMoreMessages || isLoading) return;
    if (typeof IntersectionObserver === "undefined") return;

    const target = loadMoreRef.current;
    if (!target) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          loadMoreMessages();
        }
      },
      { rootMargin: "200px 0px" },
    );

    observer.observe(target);
    return () => observer.disconnect();
  }, [hasMoreMessages, isLoading, loadMoreMessages]);

  async function handleCreateMessage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!username.trim() || !content.trim()) {
      setErrorMessage("Preencha username e conteúdo para criar a mensagem.");
      return;
    }

    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      const response = await fetch(`${apiBaseUrl}/messages`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          username: username.trim(),
          community_id: communityId,
          content: content.trim(),
          user_ip: "127.0.0.1",
        }),
      });

      if (!response.ok) {
        throw new Error("Falha ao criar mensagem");
      }

      const created = (await response.json()) as Message;
      setMessages((current) => [normalizeMessage(created), ...current]);
      setContent("");
    } catch {
      setErrorMessage("Não foi possível criar a mensagem.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleReaction(messageId: number, reactionType: ReactionType) {
    const userId = Number(reactionUserId);
    if (!userId) {
      setErrorMessage("Informe o ID do usuário para reagir.");
      return;
    }

    setErrorMessage(null);

    try {
      const response = await fetch(`${apiBaseUrl}/reactions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message_id: messageId, user_id: userId, reaction_type: reactionType }),
      });

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        throw new Error(payload.error || "Falha ao reagir");
      }

      const payload = await response.json();
      setMessages((current) =>
        current.map((message) => {
          if (message.id !== messageId) return message;
          const reactions = payload.reactions || DEFAULT_REACTIONS;
          const total =
            Number(reactions.like || 0) + Number(reactions.love || 0) + Number(reactions.insightful || 0);
          return {
            ...message,
            reactions,
            reaction_count: total,
          };
        }),
      );
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "Não foi possível registrar reação.");
    }
  }

  if (isLoading) {
    return (
      <main className="mx-auto max-w-4xl px-4 py-8">
        <div className="mb-4">
          <Link href="/communities" className="text-sm font-medium text-blue-600 hover:text-blue-700">
            ← Voltar para comunidades
          </Link>
        </div>
        Carregando timeline...
      </main>
    );
  }

  if (errorMessage && messages.length === 0) {
    return (
      <main className="mx-auto max-w-4xl px-4 py-8">
        <div className="mb-4">
          <Link href="/communities" className="text-sm font-medium text-blue-600 hover:text-blue-700">
            ← Voltar para comunidades
          </Link>
        </div>
        <div className="text-red-700">{errorMessage}</div>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-4xl px-4 py-8">
      <div className="mb-4">
        <Link href="/communities" className="text-sm font-medium text-blue-600 hover:text-blue-700">
          ← Voltar para comunidades
        </Link>
      </div>

      <header className="mb-6">
        <h1 className="text-2xl font-bold text-gray-100">{community?.name || `Comunidade #${communityId}`}</h1>
        <p className="mt-2 text-sm text-gray-600">{community?.description || "Sem descrição."}</p>
      </header>

      <section className="mb-6 rounded-lg border border-gray-200 bg-white p-4">
        <h2 className="text-lg font-semibold text-gray-900">Nova mensagem</h2>
        <form className="mt-4 space-y-3" onSubmit={handleCreateMessage}>
          <input
            value={username}
            onChange={(event) => setUsername(event.target.value)}
            placeholder="Username"
            className="w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-500"
          />
          <textarea
            value={content}
            onChange={(event) => setContent(event.target.value)}
            placeholder="Conteúdo da mensagem"
            className="min-h-24 w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-500"
          />
          <button
            type="submit"
            disabled={isSubmitting}
            className="rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
          >
            {isSubmitting ? "Enviando..." : "Enviar"}
          </button>
        </form>
      </section>

      <section className="mb-4 rounded-lg border border-gray-200 bg-white p-4">
        <label className="mb-2 block text-sm font-medium text-gray-700" htmlFor="reaction-user-id">
          ID do usuário para reagir
        </label>
        <input
          id="reaction-user-id"
          value={reactionUserId}
          onChange={(event) => setReactionUserId(event.target.value)}
          placeholder="Ex.: 1"
          className="w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-500"
        />
      </section>

      {errorMessage && (
        <div className="mb-4 rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">{errorMessage}</div>
      )}

      <section className="space-y-4">
        {orderedMessages.length === 0 ? (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-700">
            Nenhuma mensagem encontrada para esta comunidade.
          </div>
        ) : (
          orderedMessages.map((message) => (
            <article key={message.id} className="rounded-lg border border-gray-200 bg-white p-4">
              <div className="mb-2 flex items-center justify-between gap-3">
                <span className="text-sm font-semibold text-gray-900">@{message.username}</span>
                <span className="text-xs text-gray-500">
                  {message.created_at ? new Date(message.created_at).toLocaleString("pt-BR") : "Data indisponível"}
                </span>
              </div>

              <p className="text-sm text-gray-800">{message.content}</p>

              <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-gray-600">
                <span>{sentimentLabel(message.ai_sentiment_score)}</span>
                <span>Reações: {message.reaction_count}</span>
                <span>Comentários: {message.reply_count}</span>
              </div>

              <div className="mt-3 flex flex-wrap gap-2">
                {(["like", "love", "insightful"] as ReactionType[]).map((type) => (
                  <button
                    key={type}
                    onClick={() => handleReaction(message.id, type)}
                    className="rounded border border-gray-300 px-3 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50"
                    type="button"
                  >
                    {type} ({message.reactions?.[type] ?? 0})
                  </button>
                ))}
              </div>

              <Link
                href={`/messages/${message.id}?community_id=${communityId}`}
                className="mt-4 inline-block text-sm font-medium text-blue-600 hover:text-blue-700"
              >
                Ver thread
              </Link>
            </article>
          ))
        )}

        <div ref={loadMoreRef} className="h-1 w-full" aria-hidden="true" />
        {isLoadingMore && <p className="text-sm text-gray-600">Carregando mais mensagens...</p>}
      </section>
    </main>
  );
}
