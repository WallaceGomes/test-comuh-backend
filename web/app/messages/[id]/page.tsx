"use client";

import Link from "next/link";
import { useParams, useSearchParams } from "next/navigation";
import { FormEvent, useEffect, useMemo, useState } from "react";

type Message = {
  id: number;
  content: string;
  user?: { id: number; username: string };
  username?: string;
  ai_sentiment_score: number | null;
  reaction_count: number;
  reply_count: number;
  created_at?: string;
};

type LocalComment = {
  id: number;
  username: string;
  content: string;
  created_at: string;
};

function sentimentLabel(score: number | null): string {
  if (score == null) return "😐 Neutro";
  if (score > 0.2) return "😊 Positivo";
  if (score < -0.2) return "☹️ Negativo";
  return "😐 Neutro";
}

function normalizeMessage(raw: Message): Message {
  return {
    ...raw,
    username: raw.user?.username ?? raw.username ?? "desconhecido",
    reaction_count: raw.reaction_count ?? 0,
    reply_count: raw.reply_count ?? 0,
  };
}

export default function MessageThreadPage() {
  const params = useParams<{ id: string }>();
  const searchParams = useSearchParams();

  const messageId = Number(params.id);
  const initialCommunityId = searchParams.get("community_id") || "";
  const apiBaseUrl = useMemo(() => {
    if (process.env.NEXT_PUBLIC_API_BASE_URL) {
      return process.env.NEXT_PUBLIC_API_BASE_URL;
    }

    if (typeof window !== "undefined") {
      return `${window.location.protocol}//${window.location.hostname}:3000/api/v1`;
    }

    return "http://localhost:3000/api/v1";
  }, []);

  const [communityId, setCommunityId] = useState(initialCommunityId);
  const [message, setMessage] = useState<Message | null>(null);
  const [comments, setComments] = useState<LocalComment[]>([]);

  const [username, setUsername] = useState("");
  const [content, setContent] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const orderedComments = useMemo(() => {
    return [...comments].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  }, [comments]);

  useEffect(() => {
    const saved = localStorage.getItem(`message:${messageId}:comments`);
    if (!saved) return;

    try {
      const parsed = JSON.parse(saved) as LocalComment[];
      if (Array.isArray(parsed)) {
        setComments(parsed);
      }
    } catch {
      // noop
    }
  }, [messageId]);

  useEffect(() => {
    localStorage.setItem(`message:${messageId}:comments`, JSON.stringify(comments));
  }, [comments, messageId]);

  useEffect(() => {
    let isMounted = true;

    async function loadMessage() {
      if (!communityId) {
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      setErrorMessage(null);

      try {
        const response = await fetch(`${apiBaseUrl}/communities/${communityId}/messages/top?limit=50`, {
          cache: "no-store",
        });

        if (!response.ok) {
          throw new Error("Falha ao carregar mensagens da comunidade");
        }

        const data = await response.json();
        const list: Message[] = Array.isArray(data.messages)
          ? data.messages.map((raw: Message) => normalizeMessage(raw))
          : [];

        if (!isMounted) return;

        const current = list.find((item) => item.id === messageId) || null;
        setMessage(current);
        if (!current) {
          setErrorMessage("Mensagem não encontrada entre as últimas 50 da comunidade.");
        }
      } catch {
        if (isMounted) {
          setErrorMessage("Não foi possível carregar a thread.");
        }
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    }

    if (!Number.isNaN(messageId)) {
      loadMessage();
    }

    return () => {
      isMounted = false;
    };
  }, [apiBaseUrl, communityId, messageId]);

  async function handleCreateComment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!username.trim() || !content.trim() || !communityId) {
      setErrorMessage("Preencha community_id, username e conteúdo para comentar.");
      return;
    }

    setErrorMessage(null);
    setIsSubmitting(true);

    try {
      const response = await fetch(`${apiBaseUrl}/messages`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          username: username.trim(),
          community_id: Number(communityId),
          parent_message_id: messageId,
          content: content.trim(),
          user_ip: "127.0.0.1",
        }),
      });

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        throw new Error(payload.error || "Falha ao criar comentário");
      }

      const created = await response.json();
      const newComment: LocalComment = {
        id: created.id,
        username: created.username || username.trim(),
        content: created.content || content.trim(),
        created_at: created.created_at || new Date().toISOString(),
      };

      setComments((current) => [newComment, ...current]);
      setContent("");
      setMessage((current) =>
        current
          ? {
              ...current,
              reply_count: (current.reply_count || 0) + 1,
            }
          : current,
      );
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "Não foi possível criar comentário.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="mx-auto max-w-3xl px-4 py-8">
      <div className="mb-4">
        <Link href="/communities" className="text-sm font-medium text-blue-600 hover:text-blue-700">
          ← Voltar para comunidades
        </Link>
      </div>

      <section className="mb-6 rounded-lg border border-gray-200 bg-white p-4">
        <h1 className="text-xl font-bold text-gray-900">Thread da Mensagem #{messageId}</h1>

        <div className="mt-3">
          <label className="mb-1 block text-sm font-medium text-gray-700" htmlFor="community-id">
            Community ID
          </label>
          <input
            id="community-id"
            value={communityId}
            onChange={(event) => setCommunityId(event.target.value)}
            placeholder="Ex.: 1"
            className="w-full rounded border border-gray-300 px-3 py-2 text-sm"
          />
        </div>

        {isLoading ? (
          <p className="mt-4 text-sm text-gray-600">Carregando mensagem principal...</p>
        ) : message ? (
          <article className="mt-4 rounded border border-gray-100 bg-gray-50 p-4">
            <div className="mb-2 flex items-center justify-between gap-3">
              <span className="text-sm font-semibold text-gray-900">@{message.username}</span>
              <span className="text-xs text-gray-500">
                {message.created_at ? new Date(message.created_at).toLocaleString("pt-BR") : "Data indisponível"}
              </span>
            </div>
            <p className="text-sm text-gray-800">{message.content}</p>
            <div className="mt-3 flex flex-wrap gap-3 text-xs text-gray-600">
              <span>{sentimentLabel(message.ai_sentiment_score)}</span>
              <span>Reações: {message.reaction_count}</span>
              <span>Comentários: {message.reply_count}</span>
            </div>
          </article>
        ) : (
          <p className="mt-4 text-sm text-gray-600">Mensagem principal indisponível no momento.</p>
        )}
      </section>

      <section className="mb-6 rounded-lg border border-gray-200 bg-white p-4">
        <h2 className="text-lg font-semibold text-gray-900">Novo comentário</h2>
        <form className="mt-4 space-y-3" onSubmit={handleCreateComment}>
          <input
            value={username}
            onChange={(event) => setUsername(event.target.value)}
            placeholder="Username"
            className="w-full rounded border border-gray-300 px-3 py-2 text-sm"
          />
          <textarea
            value={content}
            onChange={(event) => setContent(event.target.value)}
            placeholder="Conteúdo do comentário"
            className="min-h-24 w-full rounded border border-gray-300 px-3 py-2 text-sm"
          />
          <button
            type="submit"
            disabled={isSubmitting}
            className="rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
          >
            {isSubmitting ? "Enviando..." : "Comentar"}
          </button>
        </form>
      </section>

      {errorMessage && (
        <div className="mb-4 rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">{errorMessage}</div>
      )}

      <section>
        <h2 className="mb-3 text-lg font-semibold">Comentários</h2>

        {orderedComments.length === 0 ? (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-700">
            Nenhum comentário ainda.
          </div>
        ) : (
          <div className="space-y-3">
            {orderedComments.map((comment) => (
              <article key={comment.id} className="ml-4 rounded-lg border border-gray-200 bg-white p-4">
                <div className="mb-2 flex items-center justify-between gap-3">
                  <span className="text-sm font-semibold text-gray-900">@{comment.username}</span>
                  <span className="text-xs text-gray-500">
                    {new Date(comment.created_at).toLocaleString("pt-BR")}
                  </span>
                </div>
                <p className="text-sm text-gray-800">{comment.content}</p>
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
