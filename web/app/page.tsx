import Link from "next/link";

type Community = {
  id: number;
  name: string;
  description: string | null;
  messages_count?: number;
  message_count?: number;
};

async function fetchCommunities(): Promise<Community[]> {
  const apiBaseUrl = process.env.API_INTERNAL_BASE_URL || "http://api:3000/api/v1";

  const response = await fetch(`${apiBaseUrl}/communities`, {
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error("Failed to fetch communities");
  }

  const data = await response.json();
  return Array.isArray(data.communities) ? data.communities : [];
}

function getMessageCount(community: Community): number {
  if (typeof community.messages_count === "number") return community.messages_count;
  if (typeof community.message_count === "number") return community.message_count;
  return 0;
}

export default async function HomePage() {
  let communities: Community[] = [];
  let hasError = false;

  try {
    communities = await fetchCommunities();
  } catch {
    hasError = true;
  }

  return (
    <main className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
      <header className="mb-8">
        <h1 className="text-2xl font-bold text-gray-100">Comunidades</h1>
        <p className="mt-2 text-sm text-gray-600">Lista de comunidades disponíveis.</p>
      </header>

      {hasError ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          Não foi possível carregar as comunidades.
        </div>
      ) : communities.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-gray-700">
          Nenhuma comunidade encontrada.
        </div>
      ) : (
        <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {communities.map((community) => (
            <article key={community.id} className="rounded-lg border border-gray-200 bg-white p-4">
              <h2 className="text-lg font-semibold text-gray-900">{community.name}</h2>
              <p className="mt-2 text-sm text-gray-600">{community.description || "Sem descrição."}</p>
              <p className="mt-3 text-sm font-medium text-gray-800">
                Mensagens: {getMessageCount(community)}
              </p>
              <Link
                href={`/communities/${community.id}`}
                className="mt-4 inline-block text-sm font-medium text-blue-600 hover:text-blue-700"
              >
                Acessar comunidade
              </Link>
            </article>
          ))}
        </section>
      )}
    </main>
  );
}
