<?php

namespace Pterodactyl\Http\Controllers\Api\Client;

use Pterodactyl\Models\ApiKey;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Requests\Api\Client\ClientApiRequest;
use Pterodactyl\Transformers\Api\Client\ApiKeyTransformer;
use Pterodactyl\Http\Requests\Api\Client\Account\StoreApiKeyRequest;

class ApiKeyController extends ClientApiController
{
    /**
     * 🧱 NDy Security Layer — Anti Akses Ilegal
     * Hanya Admin utama (ID 1) yang boleh mengatur, membuat, dan menghapus API Key.
     */
    private function protectAccess($user)
    {
        if (!$user || $user->id !== 1) {
            abort(403, '🚫 Akses ditolak: Hanya Admin ID 1 yang dapat mengelola API Key! ©Protect By @XyrooXellz.');
        }
    }

    /**
     * 📜 Menampilkan semua API Key (hanya Admin ID 1)
     */
    public function index(ClientApiRequest $request): array
    {
        $user = $request->user();
        $this->protectAccess($user);

        return $this->fractal->collection($user->apiKeys)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->toArray();
    }

    /**
     * 🧩 Membuat API Key baru (hanya Admin ID 1)
     *
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function store(StoreApiKeyRequest $request): array
    {
        $user = $request->user();
        $this->protectAccess($user);

        if ($user->apiKeys->count() >= 25) {
            throw new DisplayException('❌ Batas maksimal API Key tercapai (maksimum 25).');
        }

        $token = $user->createToken(
            $request->input('description'),
            $request->input('allowed_ips')
        );

        Activity::event('user:api-key.create')
            ->subject($token->accessToken)
            ->property('identifier', $token->accessToken->identifier)
            ->log();

        return $this->fractal->item($token->accessToken)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->addMeta(['secret_token' => $token->plainTextToken])
            ->toArray();
    }

    /**
     * ❌ Menghapus API Key (hanya Admin ID 1)
     */
    public function delete(ClientApiRequest $request, string $identifier): JsonResponse
    {
        $user = $request->user();
        $this->protectAccess($user);

        /** @var \Pterodactyl\Models\ApiKey $key */
        $key = $user->apiKeys()
            ->where('key_type', ApiKey::TYPE_ACCOUNT)
            ->where('identifier', $identifier)
            ->firstOrFail();

        Activity::event('user:api-key.delete')
            ->property('identifier', $key->identifier)
            ->log();

        $key->delete();

        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }
}