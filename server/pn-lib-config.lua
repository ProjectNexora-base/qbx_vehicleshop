--- PN Base: expose les réglages essentiels de cette ressource à pn-lib (panel web + /configpn en jeu).
--- Sans effet si pn-lib n'est pas installé. Les valeurs sont lues à l'usage : les changements sont appliqués en direct.
local FIELDS = {
    { source = 'config.server', key = 'commissionRate', label = 'Commission du vendeur', description = 'Part du prix versée au vendeur (0.1 = 10 %)', valueType = 'number', min = 0, max = 1 },
    { source = 'config.server', key = 'saleTimeout', label = 'Délai entre deux ventes/dons (ms)', valueType = 'number', min = 0, max = 3600000 },
    { source = 'config.server', key = 'financePaymentWarning', path = 'finance.paymentWarning', label = 'Délai avant saisie (minutes)', valueType = 'number', min = 0, max = 1440 },
    { source = 'config.server', key = 'financePaymentInterval', path = 'finance.paymentInterval', label = 'Intervalle entre paiements (heures)', valueType = 'number', min = 1, max = 720 },
    { source = 'config.server', key = 'financePreventSelling', path = 'finance.preventSelling', label = 'Interdire la vente d\'un véhicule financé', valueType = 'boolean' },
    { source = 'config.server', key = 'deleteUnpaidFinancedVehicle', label = 'Supprimer les véhicules impayés', description = 'Sinon le véhicule est seulement masqué', valueType = 'boolean' },
}

local function resolve(root, path)
    local holder, last = root, path
    for part in path:gmatch('([^%.]+)%.') do
        holder = holder[part]
        if type(holder) ~= 'table' then return nil end
    end
    return holder, path:match('([^%.]+)$') or last
end

CreateThread(function()
    if GetResourceState('pn-lib') == 'missing' then return end
    local waited = 0
    while GetResourceState('pn-lib') ~= 'started' do
        Wait(500)
        waited = waited + 500
        if waited >= 120000 then return end
    end

    local ns = GetCurrentResourceName()
    local ok, err = pcall(function()
        local schema, targets = {}, {}
        for i = 1, #FIELDS do
            local f = FIELDS[i]
            local holder, last = resolve(require(f.source), f.path or f.key)
            if holder and holder[last] ~= nil then
                targets[f.key] = { holder = holder, last = last }
                schema[#schema + 1] = {
                    key = f.key, label = f.label, description = f.description,
                    valueType = f.valueType, min = f.min, max = f.max,
                    default = holder[last],
                }
            else
                print(('[%s] réglage pn-lib ignoré (introuvable): %s.%s'):format(ns, f.source, f.key))
            end
        end

        exports['pn-lib']:RegisterConfig(ns, schema)

        for i = 1, #schema do
            local key = schema[i].key
            local t = targets[key]
            local current = exports['pn-lib']:GetConfig(ns, key)
            if current ~= nil then t.holder[t.last] = current end
            exports['pn-lib']:OnConfigChange(ns, key, function(value)
                if value ~= nil then t.holder[t.last] = value end
            end)
        end
    end)
    if not ok then
        print(('[%s] configuration pn-lib indisponible: %s'):format(ns, tostring(err)))
    end
end)
