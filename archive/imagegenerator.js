const fetch = require('node-fetch');
const fs = require('fs');

// GitHub Repository Details
const username = 'valevasqc';
const repo = 'xepi2024';
const folders = ['cuadros','juguetes','cajitas','rompecabezas','rotulos','aviones','casitas']; // Add all categories here
const branch = 'main';

async function fetchImageLinks() {
    try {
        const imageLinks = {};

        for (let folder of folders) {
            const apiUrl = `https://api.github.com/repos/${username}/${repo}/contents/productos/${folder}?ref=${branch}`;
            const response = await fetch(apiUrl);
            const files = await response.json();

            imageLinks[folder] = files
                .filter(file => file.download_url)
                .reduce((acc, file) => {
                    acc[file.name.replace(/\.[^/.]+$/, "s")] = file.download_url + '?raw=true';
                    // console.log(acc);
                    return acc;
                }, {});
        }

        // Save JSON to file
        fs.writeFileSync('images.json', JSON.stringify({ images: imageLinks }, null, 2));
        console.log('images.json has been created successfully!');
    } catch (error) {
        console.error('Error fetching images:', error);
    }
}

fetchImageLinks();
