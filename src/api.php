<?php
// Define que a resposta será em texto plano
header('Content-Type: text/plain');

// Verifica se a requisição é do tipo POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Pega o comando enviado pelo JavaScript
    $command = $_POST['command'];

    // --- PONTO IMPORTANTE DE SEGURANÇA ---
    // Executar comandos recebidos diretamente do usuário é EXTREMAMENTE PERIGOSO
    // em um ambiente real. Para este projeto acadêmico, é um ponto de partida.
    // Em um sistema de produção, você precisaria validar e "sanitizar" essa entrada
    // para evitar ataques de injeção de comando.

    // Verifica se o comando não está vazio
    if (!empty($command)) {
        // Constrói o comando final para ser executado em um novo namespace
        // 'unshare -p -f --mount-proc' cria um novo processo isolado
        // '2>&1' redireciona a saída de erro para a saída padrão, para que possamos ver os erros
        $full_command = 'unshare -p -f --mount-proc ' . $command . ' 2>&1';

        // Executa o comando no shell do servidor e captura a saída
        $output = shell_exec($full_command);

        // Retorna a saída para o JavaScript
        echo $output;
    } else {
        echo 'Erro: Nenhum comando recebido.';
    }
} else {
    // Se a requisição não for POST, retorna um erro
    echo 'Erro: Requisição inválida.';
}
?>