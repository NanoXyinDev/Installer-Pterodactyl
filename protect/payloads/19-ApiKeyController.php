<?php

namespace Pterodactyl\Http\Controllers\Api\Client;

use Pterodactyl\Models\ApiKey;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Facades\Activity;
use Illuminate\Support\Facades\DB;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Requests\Api\Client\ClientApiRequest;
use Pterodactyl\Transformers\Api\Client\ApiKeyTransformer;
use Pterodactyl\Http\Requests\Api\Client\Account\StoreApiKeyRequest;

class ApiKeyController extends ClientApiController
{
    private function protectAccess($user): void
    {
        if (!$user || (int) $user->id !== 1) {
            abort(403, 'Akses API Key hanya tersedia untuk Admin utama.');
        }
    }

    public function index(ClientApiRequest $request): array
    {
        $user = $request->user();
        $this->protectAccess($user);

        return $this->fractal->collection($user->apiKeys)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->toArray();
    }

    public function store(StoreApiKeyRequest $request): array
    {
        $user = $request->user();
        $this->protectAccess($user);

        $token = DB::transaction(function () use ($request, $user) {
            if ($user->apiKeys()->lockForUpdate()->count() >= 25) {
                throw new DisplayException('Batas maksimal API Key tercapai.');
            }

            return $user->createToken(
                $request->input('description'),
                $request->input('allowed_ips')
            );
        });

        Activity::event('user:api-key.create')
            ->subject($token->accessToken)
            ->property('identifier', $token->accessToken->identifier)
            ->log();

        return $this->fractal->item($token->accessToken)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->addMeta(['secret_token' => $token->plainTextToken])
            ->toArray();
    }

    public function delete(ClientApiRequest $request, string $identifier): JsonResponse
    {
        $user = $request->user();
        $this->protectAccess($user);

        /** @var ApiKey $key */
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
