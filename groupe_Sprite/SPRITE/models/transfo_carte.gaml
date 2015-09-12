/**
 *  transfocarte
 *  Author: Mog
 *  Description: 
 */

model transfocarte


/***********************************************
 *                   AGENT MONDE               * 
 ***********************************************/

global
{
	// *************************** VARIABLES AGENT MONDE **********************
	
	//chargement des données géographiques
	file island_shapefile <- file("../includes/contours_ile.shp");
	file sea_shapefile <- file("../includes/mer3.shp");
	file dykes_shapefile <- file("../includes/ouvrages.shp");
	file buildings_shapefile <- file("../includes/batiments.shp");
	file dem_file <- csv_file("../includes/mnt_small.csv", " ");

	//définition des géométries
	geometry shape <- envelope(file("../includes/rect.shp"));
	geometry lamer <- geometry(first(island_shapefile));
	geometry sea <- geometry(sea_shapefile);
	
	//définition des cellules de mer
	list<parcelle> sea_cells;
   	list<parcelle> merProche;
   	list<parcelle> premiercercledelamer;
   	list<parcelle> toutpremiercercledelamer;
   	list<parcelle> cellulesquiserventarien;
   	list<parcelle> cellulesquiserventaquelquechose;
	list<parcelle> cellulessanseau;

	string dossier_fichiers <-  "../includes/" ;
	string fichier_resultat <- dossier_fichiers +"grille_oleron.csv";  
		
	//paramètre des digues 
	float dyke_height;
	float dyke_width;

	
	//***************** INITIALISATION AGENT MONDE *********************
	init 
	{
		do init_cells;
		do init_water;
		do init_obstacles;
		do placer_digues_maisons;
		do save_results;
	
	}
	// fin init



	//initialisation des cellules de la grille a partir du shapefile
	action init_cells
	{
		matrix data <- matrix(dem_file);
		ask parcelle
		{
			altitude <- float(data[grid_x, grid_y]);
			altitude <- max([-2, altitude]);
		}
	}

	//initialisation de la mer a partir du shapefile
	action init_water
	{	
		ask parcelle overlapping sea
		{
			is_sea <- true;
		}

		sea_cells <- parcelle where (each.is_sea);
		premiercercledelamer <- sea_cells where each.celluleterrecote;
		loop act over: premiercercledelamer {
			act.is_sea <- false;
		}
		cellulessanseau <- parcelle - sea_cells;
	}


	//initialisation des bâtiments et des digues a partir du shapefile
	action init_obstacles
	{
	//création des bâtiments à partir des fichiers géo
		create building from: buildings_shapefile
		{
			do update_cells;
		}

		//création des bâtiments à partir des fichiers géo (avec récup de la hauteur et de l'état)
		create dyke from: dykes_shapefile with: [hauteur::float(read("hauteur")), etat::string(read("Etat_Ouvra"))];
		ask dyke
		{
			height <- hauteur / 100;
			shape <- shape + dyke_width;	
			if height<3 {typeDick<-1;} else {typeDick<-2;}
			do update_cells;
		}
	}

	//renseigne sur la présence de digue sur une cellule
	action placer_digues_maisons
	{
		ask parcelle overlapping building {
			maison <- true;
			bats <- building overlapping self;
			densite_bati <- sum(bats collect each.shape.area) / 400;
		}
	ask parcelle{
	 do compute_highest_obstacle;
	}
	}


action save_results {
		save ["altitude","is_sea", "digue","densite_bati", "obstacle_height"] to: fichier_resultat type:"csv";
		ask parcelle {
		save [altitude,is_sea, digue,densite_bati, obstacle_height] to: fichier_resultat type:"csv";
		}}
	





}
/* ******************************************************************
 ******* fin global *******                                       ***
*********************************************************************/



/********************************
* OBSTACLES : maisons et digues *
*********************************/

//spécification des obstacles et maison
species obstacle
{
	float height min: 0.0;
	string etat;
	rgb color;
	int typeDick;
	float water_pressure update: compute_water_pressure();
	list<parcelle> cells_concerned;
	list<parcelle> cells_neighbours;
	float compute_water_pressure
	{
		if (height = 0.0)
		{
			return 0.0;
		} else
		{
			if (not empty(cells_neighbours))
			{
				float water_level <- cells_neighbours max_of (each.water_height);
				return min([1.0, water_level / height]);
			}

		}

	}

	action update_cells
	{
		cells_concerned <- (parcelle overlapping self);
		ask cells_concerned
		{
			digue<-myself.typeDick;
		}
	}

	
}

species building parent: obstacle
{
	float height <- 2.0 + rnd(8);
}

species dyke parent: obstacle
{
	int counter_wp <- 0;
	int hauteur;
	int breaking_threshold <- 24;

	// s'agit-il d'une digue ecologique ou pas
	bool est_ecolo;
	
	

	// FIXME: est-ce qu'il faut copier la meme action dans building?
	// dans ce cas il faut plutot la mettre dans l'espece parente = obstacle
	action compute_height
	{
		height <- dyke_height - mean(cells_concerned collect (each.altitude));
	}


}




/***************************************
 * ******* GRILLE DE PARCELLES ******* *
 ***************************************/

grid parcelle width: 52 height: 90 neighbours: 8 frequency: 0 use_regular_agents: false use_individual_shapes: false use_neighbours_cache: false
{
	/***************************Variables pour flood****************************************/

	// altitude d'apres le MNT
	float altitude;

	// hauteur d'eau sur la cellule
	float water_height <- 0.0 min: 0.0;
	bool eau_present<- false;
	
	// hauteur du plus haut obstacle si plusieurs
	float obstacle_height <- 0.0;

	// hauteur totale agreegee = altitude + hauteur bati + hauteur eau
	float height;

	// cellules voisines (Moore, 8)
	list<parcelle> neighbour_cells;
	list<parcelle> neighbour_cells_far;
		
		
	// cellule mer / terre 
	bool is_sea <- false;

	bool celluleterrecote function: {((self neighbours_at 2) first_with not each.is_sea) != nil};
   	// parcelle de mer la plus proche et distance à la mer 
   	parcelle closestSea;
   	float distanceSea;

	// liste des obstacles situes sur cette cellule      
	list<obstacle> obstacles;

	// est-ce que la cellule a deja ete traitee dans la diffusion de l'eau
	bool already <- false;

	// calculer la hauteur du plus haut obstacle present sur cette cellule
	action compute_highest_obstacle
	{
	// si aucun obstacle : hauteur nulle
		if (empty(obstacles))
		{
			obstacle_height<- 0.0;
		}
		// sinon renvoyer le max
		else
		{
			obstacle_height<- obstacles max_of (each.height);
		}
	}

	/****************************Variables interactions parcelles **********************/

	// 0 : pas de digue, 1 : petite digue, 2 : grosse digue
	int digue <- 0;
	list<building> bats;
	float densite_bati <- 0.0;
	bool maison update: densite_bati > 0;
}

/********************
 * *** SIMULATION ***
 ********************/
experiment Displays type: gui
{

	output
	{


	} 

}
